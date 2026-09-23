"""initial schema: links, clicks

Revision ID: 0001_initial
Revises:
Create Date: 2026-09-23

"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0001_initial"
down_revision: str | None = None
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "links",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("code", sa.String(length=16), nullable=False),
        sa.Column("target_url", sa.String(length=2048), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index("ix_links_code", "links", ["code"], unique=True)

    op.create_table(
        "clicks",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("code", sa.String(length=16), sa.ForeignKey("links.code"), nullable=False),
        sa.Column(
            "clicked_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("user_agent", sa.String(length=512), nullable=True),
        sa.Column("referer", sa.String(length=2048), nullable=True),
    )
    op.create_index("ix_clicks_code_clicked_at", "clicks", ["code", "clicked_at"])


def downgrade() -> None:
    op.drop_index("ix_clicks_code_clicked_at", table_name="clicks")
    op.drop_table("clicks")
    op.drop_index("ix_links_code", table_name="links")
    op.drop_table("links")
