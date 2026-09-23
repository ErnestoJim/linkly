"""End-to-end tests against real Postgres + Redis containers.

Requires a running Docker daemon (testcontainers spins up the containers).
Run with: pytest -m integration
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from testcontainers.postgres import PostgresContainer
from testcontainers.redis import RedisContainer

pytestmark = pytest.mark.integration


@pytest.fixture(scope="module")
def api_client():
    with (
        PostgresContainer("postgres:16-alpine") as postgres,
        RedisContainer("redis:7-alpine") as redis_container,
    ):
        import app.config as config_module
        import app.db as db_module
        import app.main as main_module
        from app.db import Base

        config_module.settings.database_url = postgres.get_connection_url().replace(
            "postgresql+psycopg2", "postgresql+psycopg"
        )
        config_module.settings.redis_url = (
            f"redis://{redis_container.get_container_host_ip()}:"
            f"{redis_container.get_exposed_port(6379)}/0"
        )

        db_module.engine = create_engine(config_module.settings.database_url)
        db_module.SessionLocal.configure(bind=db_module.engine)
        Base.metadata.create_all(db_module.engine)

        # SQS is exercised separately (test_queue.py); keep this test
        # focused on the DB + cache integration.
        main_module.publish_click_event = lambda **kwargs: None

        with TestClient(main_module.app) as client:
            yield client


def test_create_link_and_redirect_round_trip(api_client):
    create_resp = api_client.post("/api/links", json={"url": "https://example.com/page"})
    assert create_resp.status_code == 201
    body = create_resp.json()
    code = body["code"]
    assert body["short_url"].endswith(f"/{code}")

    redirect_resp = api_client.get(f"/{code}", follow_redirects=False)
    assert redirect_resp.status_code == 302
    assert redirect_resp.headers["location"] == "https://example.com/page"

    # Second hit should be served from the Redis cache rather than Postgres.
    cached_resp = api_client.get(f"/{code}", follow_redirects=False)
    assert cached_resp.status_code == 302
    assert cached_resp.headers["location"] == "https://example.com/page"


def test_redirect_for_unknown_code_is_404(api_client):
    resp = api_client.get("/does-not-exist", follow_redirects=False)
    assert resp.status_code == 404


def test_stats_for_unknown_code_is_404(api_client):
    resp = api_client.get("/api/links/does-not-exist/stats")
    assert resp.status_code == 404


def test_readyz_reports_ready_with_real_dependencies(api_client):
    resp = api_client.get("/readyz")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ready"}


def test_create_link_rejects_invalid_scheme(api_client):
    resp = api_client.post("/api/links", json={"url": "ftp://example.com"})
    assert resp.status_code == 422
