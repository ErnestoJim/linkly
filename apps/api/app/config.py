from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg://linkly:linkly@localhost:5432/linkly"
    redis_url: str = "redis://localhost:6379/0"
    sqs_queue_url: str = "http://localhost:9324/000000000000/linkly-clicks"
    aws_endpoint_url: str | None = None
    aws_region: str = "us-east-1"

    base_url: str = "http://localhost:8000"
    cache_ttl_seconds: int = 3600
    code_length: int = 6
    code_generation_attempts: int = 5


settings = Settings()
