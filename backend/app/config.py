from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    SECRET_KEY: str = "dev-secret-key-not-for-production"
    AIHUBMIX_API_KEY: str = ""
    AI_MODEL: str = "glm-4.9-flash"
    ASR_MODEL: str = "gemini-2.5-flash"  # 语音转文字模型（OpenAI 兼容 input_audio）
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
