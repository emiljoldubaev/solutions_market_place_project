from pydantic_settings import BaseSettings
from typing import List
import os


class Settings(BaseSettings):
    DATABASE_URL: str = "mysql+pymysql://root:password@localhost:3306/marketplace_db"
    JWT_SECRET_KEY: str = "your-super-secret-jwt-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    UPLOAD_DIR: str = "uploads"
    MAX_IMAGE_SIZE_MB: int = 10
    MAX_ATTACHMENT_SIZE_MB: int = 5
    MAX_IMAGES_PER_LISTING: int = 5
    ALLOWED_IMAGE_TYPES: str = "image/jpeg,image/png,image/webp"
    ALLOWED_ATTACHMENT_TYPES: str = "image/jpeg,image/png,image/webp,application/pdf"
    ADMIN_EMAIL: str = "admin@marketplace.com"
    ADMIN_PASSWORD: str = "admin123"

    @property
    def allowed_image_types_list(self) -> List[str]:
        return [t.strip() for t in self.ALLOWED_IMAGE_TYPES.split(",")]

    @property
    def allowed_attachment_types_list(self) -> List[str]:
        return [t.strip() for t in self.ALLOWED_ATTACHMENT_TYPES.split(",")]

    @property
    def max_image_size_bytes(self) -> int:
        return self.MAX_IMAGE_SIZE_MB * 1024 * 1024

    @property
    def max_attachment_size_bytes(self) -> int:
        return self.MAX_ATTACHMENT_SIZE_MB * 1024 * 1024

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()

# Ensure upload directories exist
for subdir in ["listings", "profiles", "attachments"]:
    os.makedirs(os.path.join(settings.UPLOAD_DIR, subdir), exist_ok=True)
