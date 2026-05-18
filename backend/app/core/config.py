from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "Services à la Demande"
    APP_ENV: str = "development"
    DEBUG: bool = True
    SECRET_KEY: str = "change-me"
    CORS_ORIGINS: str = "http://localhost:3000"

    MONGODB_URL: str = ""
    DB_NAME: str = "services_app"

    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    UPLOAD_DIR: str = "./uploads"
    MAX_FILE_SIZE_MB: int = 10
    STATIC_URL: str = "http://localhost:8000/static"

    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    EMAIL_FROM: str = "Services App <noreply@example.com>"

    PUSH_NOTIFICATIONS_ENABLED: bool = False
    SMS_ENABLED: bool = False
    GOOGLE_OAUTH_ENABLED: bool = False
    GOOGLE_MAPS_ENABLED: bool = False
    OCR_ENABLED: bool = False
    CLOUD_STORAGE_ENABLED: bool = False
    REDIS_ENABLED: bool = False

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
