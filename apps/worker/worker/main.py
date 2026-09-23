import logging
import signal
import threading
from types import FrameType

import boto3
from botocore.exceptions import EndpointConnectionError
from prometheus_client import start_http_server

from worker.config import settings
from worker.consumer import process_batch
from worker.db import SessionLocal
from worker.metrics import worker_errors_total

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("linkly.worker")

_shutdown = threading.Event()
_RETRY_BACKOFF_SECONDS = 5


def _handle_sigterm(signum: int, frame: FrameType | None) -> None:
    logger.info("received signal %s, shutting down after current batch", signum)
    _shutdown.set()


def run() -> None:
    signal.signal(signal.SIGTERM, _handle_sigterm)
    signal.signal(signal.SIGINT, _handle_sigterm)

    start_http_server(settings.metrics_port)
    logger.info("linkly worker started, polling %s", settings.sqs_queue_url)

    sqs_client = boto3.client(
        "sqs",
        region_name=settings.aws_region,
        endpoint_url=settings.aws_endpoint_url,
    )

    while not _shutdown.is_set():
        try:
            response = sqs_client.receive_message(
                QueueUrl=settings.sqs_queue_url,
                MaxNumberOfMessages=settings.max_messages,
                WaitTimeSeconds=settings.wait_time_seconds,
            )
        except EndpointConnectionError:
            logger.warning("SQS endpoint not reachable yet, retrying in %ds", _RETRY_BACKOFF_SECONDS)
            worker_errors_total.inc()
            _shutdown.wait(_RETRY_BACKOFF_SECONDS)
            continue

        messages = response.get("Messages", [])
        if not messages:
            continue

        db_session = SessionLocal()
        try:
            processed = process_batch(sqs_client, db_session, settings.sqs_queue_url, messages)
            logger.info("processed %d clicks", processed)
        finally:
            db_session.close()

    logger.info("linkly worker stopped")


if __name__ == "__main__":
    run()
