import pytest


@pytest.fixture(autouse=True)
def _clear_singleton_clients():
    from app.cache import get_redis
    from app.queue import get_sqs_client

    get_redis.cache_clear()
    get_sqs_client.cache_clear()
    yield
    get_redis.cache_clear()
    get_sqs_client.cache_clear()
