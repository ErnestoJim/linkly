import logging

from fastapi import Depends, FastAPI, HTTPException, Request
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from redis.exceptions import RedisError
from sqlalchemy import func, text
from sqlalchemy.exc import IntegrityError, OperationalError
from sqlalchemy.orm import Session
from starlette.responses import RedirectResponse, Response

from app.cache import get_cached_target, get_redis, set_cached_target
from app.codes import generate_code
from app.config import settings
from app.db import get_db
from app.logging import configure_logging, request_id_middleware
from app.metrics import (
    cache_hits_total,
    cache_misses_total,
    redirect_latency_seconds,
    redirects_total,
)
from app.models import Click, Link
from app.queue import publish_click_event
from app.schemas import ClicksByDay, CreateLinkRequest, CreateLinkResponse, LinkStatsResponse

configure_logging()
logger = logging.getLogger("linkly.api")

app = FastAPI(title="Linkly API")
app.middleware("http")(request_id_middleware)


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/readyz")
def readyz(db: Session = Depends(get_db)) -> dict[str, str]:
    try:
        db.execute(text("SELECT 1"))
    except OperationalError as exc:
        raise HTTPException(status_code=503, detail="database unavailable") from exc

    try:
        get_redis().ping()
    except RedisError as exc:
        raise HTTPException(status_code=503, detail="cache unavailable") from exc

    return {"status": "ready"}


@app.get("/metrics")
def metrics() -> Response:
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/api/links", response_model=CreateLinkResponse, status_code=201)
def create_link(payload: CreateLinkRequest, db: Session = Depends(get_db)) -> CreateLinkResponse:
    for _ in range(settings.code_generation_attempts):
        code = generate_code(settings.code_length)
        link = Link(code=code, target_url=payload.url)
        db.add(link)
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            continue
        return CreateLinkResponse(code=code, short_url=f"{settings.base_url}/{code}")

    raise HTTPException(status_code=500, detail="could not generate a unique code")


@app.get("/{code}")
def redirect(code: str, request: Request, db: Session = Depends(get_db)) -> RedirectResponse:
    with redirect_latency_seconds.time():
        target_url = get_cached_target(code)
        if target_url is not None:
            cache_hits_total.inc()
        else:
            cache_misses_total.inc()
            link = db.query(Link).filter(Link.code == code).first()
            if link is None:
                raise HTTPException(status_code=404, detail="link not found")
            target_url = link.target_url
            set_cached_target(code, target_url, settings.cache_ttl_seconds)

        try:
            publish_click_event(
                code=code,
                user_agent=request.headers.get("user-agent"),
                referer=request.headers.get("referer"),
            )
        except Exception:
            logger.exception("failed to publish click event for code=%s", code)

        redirects_total.inc()
        return RedirectResponse(url=target_url, status_code=302)


@app.get("/api/links/{code}/stats", response_model=LinkStatsResponse)
def link_stats(code: str, db: Session = Depends(get_db)) -> LinkStatsResponse:
    link = db.query(Link).filter(Link.code == code).first()
    if link is None:
        raise HTTPException(status_code=404, detail="link not found")

    total_clicks = db.query(func.count(Click.id)).filter(Click.code == code).scalar() or 0

    by_day_rows = (
        db.query(
            func.date(Click.clicked_at).label("day"),
            func.count(Click.id).label("clicks"),
        )
        .filter(Click.code == code)
        .group_by(func.date(Click.clicked_at))
        .order_by(func.date(Click.clicked_at))
        .all()
    )

    return LinkStatsResponse(
        code=code,
        total_clicks=total_clicks,
        clicks_by_day=[ClicksByDay(date=row.day, clicks=row.clicks) for row in by_day_rows],
    )
