from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    SECRET_KEY: str = "dev-secret-key-not-for-production"
    AIHUBMIX_API_KEY: str = ""
    AI_MODEL: str = "glm-4.9-flash"
    ASR_MODEL: str = "whisper-large-v3"  # 语音转文字模型（专用ASR，实测1.8s/次，比gemini-2.5-pro快2.5倍）
    AI_BASE_URL: str = "https://aihubmix.com/v1"
    PORT: int = 8000

    # JWT 有效期（天）
    TOKEN_EXPIRE_DAYS: int = 30

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache
def get_settings() -> Settings:
    return Settings()
