import datetime
import json
from functools import lru_cache
from typing import Any

import boto3

from app.config import settings


@lru_cache
def get_sqs_client() -> Any:
    return boto3.client(
        "sqs",
        region_name=settings.aws_region,
        endpoint_url=settings.aws_endpoint_url,
    )


def publish_click_event(code: str, user_agent: str | None, referer: str | None) -> None:
    message = {
        "code": code,
        "ts": datetime.datetime.now(datetime.UTC).isoformat(),
        "user_agent": user_agent,
        "referer": referer,
    }
    get_sqs_client().send_message(
        QueueUrl=settings.sqs_queue_url,
        MessageBody=json.dumps(message),
    )
