import fakeredis

from app import cache


def test_get_cached_target_is_none_when_missing(monkeypatch):
    fake = fakeredis.FakeRedis(decode_responses=True)
    monkeypatch.setattr(cache, "get_redis", lambda: fake)

    assert cache.get_cached_target("missing") is None


def test_set_then_get_cached_target_round_trips(monkeypatch):
    fake = fakeredis.FakeRedis(decode_responses=True)
    monkeypatch.setattr(cache, "get_redis", lambda: fake)

    cache.set_cached_target("abc123", "https://example.com", ttl_seconds=60)

    assert cache.get_cached_target("abc123") == "https://example.com"


def test_set_cached_target_applies_ttl(monkeypatch):
    fake = fakeredis.FakeRedis(decode_responses=True)
    monkeypatch.setattr(cache, "get_redis", lambda: fake)

    cache.set_cached_target("abc123", "https://example.com", ttl_seconds=60)

    ttl = fake.ttl("link:abc123")
    assert 0 < ttl <= 60
