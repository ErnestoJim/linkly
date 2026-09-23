from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg://linkly:linkly@localhost:5432/linkly"
    sqs_queue_url: str = "http://localhost:9324/000000000000/linkly-clicks"
    aws_endpoint_url: str | None = None
    aws_region: str = "us-east-1"

    wait_time_seconds: int = 20
    max_messages: int = 10
    metrics_port: int = 9000


settings = Settings()
