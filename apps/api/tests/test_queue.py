import json

import boto3
from moto import mock_aws

from app import queue


@mock_aws
def test_publish_click_event_sends_message(monkeypatch):
    sqs = boto3.client("sqs", region_name="us-east-1")
    created = sqs.create_queue(QueueName="linkly-clicks")
    queue_url = created["QueueUrl"]

    monkeypatch.setattr(queue.settings, "sqs_queue_url", queue_url)
    monkeypatch.setattr(queue.settings, "aws_region", "us-east-1")
    monkeypatch.setattr(queue.settings, "aws_endpoint_url", None)

    queue.publish_click_event(code="abc123", user_agent="pytest", referer="https://ref.example")

    received = sqs.receive_message(QueueUrl=queue_url, WaitTimeSeconds=1)
    [message] = received["Messages"]
    body = json.loads(message["Body"])

    assert body["code"] == "abc123"
    assert body["user_agent"] == "pytest"
    assert body["referer"] == "https://ref.example"
    assert "ts" in body
