import datetime

from pydantic import BaseModel, field_validator

from app.codes import InvalidUrlError, validate_url


class CreateLinkRequest(BaseModel):
    url: str

    @field_validator("url")
    @classmethod
    def check_scheme(cls, value: str) -> str:
        try:
            return validate_url(value)
        except InvalidUrlError as exc:
            raise ValueError(str(exc)) from exc


class CreateLinkResponse(BaseModel):
    code: str
    short_url: str


class ClicksByDay(BaseModel):
    date: datetime.date
    clicks: int


class LinkStatsResponse(BaseModel):
    code: str
    total_clicks: int
    clicks_by_day: list[ClicksByDay]
