from functools import lru_cache

import redis

from app.config import settings


@lru_cache
def get_redis() -> redis.Redis:
    return redis.Redis.from_url(settings.redis_url, decode_responses=True)


def get_cached_target(code: str) -> str | None:
    value = get_redis().get(f"link:{code}")
    return value if isinstance(value, str) else None


def set_cached_target(code: str, target_url: str, ttl_seconds: int) -> None:
    get_redis().set(f"link:{code}", target_url, ex=ttl_seconds)
