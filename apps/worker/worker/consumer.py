import datetime
import json
import logging
from collections.abc import Mapping, Sequence
from typing import Any

from worker.db import Click
from worker.metrics import clicks_processed_total, worker_errors_total

logger = logging.getLogger("linkly.worker")


def parse_message(body: str) -> Click:
    data = json.loads(body)
    return Click(
        code=data["code"],
        clicked_at=datetime.datetime.fromisoformat(data["ts"]),
        user_agent=data.get("user_agent"),
        referer=data.get("referer"),
    )


def process_batch(
    sqs_client: Any,
    db_session: Any,
    queue_url: str,
    messages: Sequence[Mapping[str, Any]],
) -> int:
    if not messages:
        return 0

    clicks: list[Click] = []
    valid_messages: list[Mapping[str, Any]] = []
    for message in messages:
        try:
            clicks.append(parse_message(message["Body"]))
            valid_messages.append(message)
        except (KeyError, ValueError, json.JSONDecodeError):
            logger.exception("dropping malformed message: %s", message.get("MessageId"))
            worker_errors_total.inc()
            # A malformed message will never parse successfully, so delete it
            # instead of letting it retry into the DLQ for no reason.
            valid_messages.append(message)

    try:
        db_session.add_all(clicks)
        db_session.commit()
    except Exception:
        db_session.rollback()
        logger.exception("failed to persist batch of %d clicks", len(clicks))
        worker_errors_total.inc()
        return 0

    clicks_processed_total.inc(len(clicks))

    sqs_client.delete_message_batch(
        QueueUrl=queue_url,
        Entries=[
            {"Id": message["MessageId"], "ReceiptHandle": message["ReceiptHandle"]}
            for message in valid_messages
        ],
    )
    return len(clicks)
