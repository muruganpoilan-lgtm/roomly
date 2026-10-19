from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")

    database_url: str = "postgresql://roomly:roomly@localhost:5432/roomly"
    jwt_secret: str = "dev-secret-change-me"
    jwt_hours: int = 24 * 7
    hold_minutes: int = 10
    # Dev only: lets a guest confirm a held booking without paying. Keep False in production.
    allow_fake_confirm: bool = False

    # Razorpay (https://dashboard.razorpay.com/app/keys). Leave empty to keep payments off.
    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""
    razorpay_webhook_secret: str = ""
    razorpay_api_base: str = "https://api.razorpay.com/v1"
    # Cancelling at least this many hours before check-in refunds everything; later cancellations get no refund.
    refund_full_hours: int = 48

    # Photo uploads. Local disk for development; swap storage.py for S3 or Cloudinary in production.
    upload_dir: str = "uploads"
    public_base_url: str = "http://localhost:8000"
    max_upload_mb: int = 5
    max_photos_per_item: int = 20


settings = Settings()


def payments_enabled() -> bool:
    return bool(settings.razorpay_key_id and settings.razorpay_key_secret)
