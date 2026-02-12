"""Application configuration loaded from environment variables."""

from pydantic_settings import BaseSettings
from typing import List, Optional
import json


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Situation Room Agent"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True

    # OpenAI
    OPENAI_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4-turbo"
    OPENAI_EMBEDDING_MODEL: str = "text-embedding-3-small"

    # Pinecone
    PINECONE_API_KEY: str = ""
    PINECONE_ENVIRONMENT: str = "us-east-1"
    PINECONE_INDEX_NAME: str = "situation-room"

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./situation_room.db"
    DATABASE_URL_SYNC: str = "sqlite:///./situation_room.db"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # JWT
    JWT_SECRET_KEY: str = "change-me-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # CORS
    CORS_ORIGINS: str = '["http://localhost:3000","http://localhost:8080"]'

    # Rate Limiting
    RATE_LIMIT_AUTHENTICATED: int = 200
    RATE_LIMIT_UNAUTHENTICATED: int = 60

    @property
    def cors_origins_list(self) -> List[str]:
        try:
            return json.loads(self.CORS_ORIGINS)
        except (json.JSONDecodeError, TypeError):
            return ["*"]

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


settings = Settings()
