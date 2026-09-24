import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Link(Base):
    __tablename__ = "links"

    id: Mapped[int] = mapped_column(primary_key=True)
    code: Mapped[str] = mapped_column(String(16), unique=True, index=True, nullable=False)
    target_url: Mapped[str] = mapped_column(String(2048), nullable=False)
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class Click(Base):
    __tablename__ = "clicks"
    __table_args__ = (Index("ix_clicks_code_clicked_at", "code", "clicked_at"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    code: Mapped[str] = mapped_column(String(16), ForeignKey("links.code"), nullable=False)
    clicked_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    user_agent: Mapped[str | None] = mapped_column(String(512), nullable=True)
    referer: Mapped[str | None] = mapped_column(String(2048), nullable=True)
