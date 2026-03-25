from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    app_name: str = "Brightroar Asset Manager"
    app_version: str = "1.0.0"
    debug: bool = False

    # Security
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    # Database — full URL (used by SQLAlchemy)
    database_url: str

    # Database — individual fields (used by Docker/Alembic)
    postgres_user: str = "brightroar"
    postgres_password: str = "brightroar123"
    postgres_db: str = "brightroar_db"
    postgres_host: str = "db"
    postgres_port: int = 5432

    # Redis — full URL (used by redis client)
    redis_url: str

    # Redis — individual fields (used by Docker)
    redis_host: str = "redis"
    redis_port: int = 6379
    redis_password: str = "redis123"

    # CORS
    allowed_origins: str = "http://localhost:3000"

    # Etherscan — on-chain balance sync
    etherscan_api_key: str = ""
    rapidapi_key: str = ""  # Get free key at https://rapidapi.com (search "Zillow Com1")  # Get free key at https://etherscan.io/myapikey

    @property
    def origins_list(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",")]

    class Config:
        env_file = ".env"
        extra = "ignore"   # silently ignore any extra env vars


@lru_cache()
def get_settings() -> Settings:
    return Settings()