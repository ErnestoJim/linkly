import json

from worker.consumer import parse_message, process_batch
from worker.db import Click


class FakeSqsClient:
    def __init__(self):
        self.deleted: list[tuple[str, list[dict]]] = []

    def delete_message_batch(self, QueueUrl, Entries):
        self.deleted.append((QueueUrl, Entries))


def _message(message_id, code="abc123", ts="2026-09-23T10:00:00+00:00", user_agent="ua", referer="ref"):
    return {
        "MessageId": message_id,
        "ReceiptHandle": f"handle-{message_id}",
        "Body": json.dumps(
            {"code": code, "ts": ts, "user_agent": user_agent, "referer": referer}
        ),
    }


def test_parse_message_builds_click():
    click = parse_message(_message("1")["Body"])
    assert click.code == "abc123"
    assert click.user_agent == "ua"
    assert click.referer == "ref"


def test_process_batch_inserts_clicks_and_deletes_messages(db_session):
    sqs = FakeSqsClient()
    messages = [_message("1"), _message("2", code="xyz789")]

    processed = process_batch(sqs, db_session, "queue-url", messages)

    assert processed == 2
    assert db_session.query(Click).count() == 2
    assert len(sqs.deleted) == 1
    _, entries = sqs.deleted[0]
    assert {e["Id"] for e in entries} == {"1", "2"}


def test_process_batch_drops_malformed_messages(db_session):
    sqs = FakeSqsClient()
    malformed = {"MessageId": "bad", "ReceiptHandle": "handle-bad", "Body": "not json"}

    processed = process_batch(sqs, db_session, "queue-url", [malformed])

    assert processed == 0
    assert db_session.query(Click).count() == 0
    _, entries = sqs.deleted[0]
    assert entries == [{"Id": "bad", "ReceiptHandle": "handle-bad"}]


def test_process_batch_with_empty_list_is_noop(db_session):
    sqs = FakeSqsClient()
    assert process_batch(sqs, db_session, "queue-url", []) == 0
    assert sqs.deleted == []


def test_process_batch_does_not_delete_when_commit_fails(db_session, monkeypatch):
    sqs = FakeSqsClient()

    def _raise_commit():
        raise RuntimeError("db down")

    monkeypatch.setattr(db_session, "commit", _raise_commit)

    processed = process_batch(sqs, db_session, "queue-url", [_message("1")])

    assert processed == 0
    assert sqs.deleted == []
