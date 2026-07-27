from functools import lru_cache
from zoneinfo import ZoneInfo

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    firebase_project_id: str = "eficiencia-energetica-ee"
    firestore_emulator_host: str = ""
    firebase_web_api_key: str = ""
    dashboard_session_secret: str = ""
    session_cookie_secure: bool = True
    dashboard_query_limit: int = 50_000
    dashboard_batch_size: int = 500
    default_timezone: str = "America/Guayaquil"

    @property
    def timezone(self) -> ZoneInfo:
        return ZoneInfo(self.default_timezone)

    def validate_runtime_secrets(self) -> None:
        if len(self.firebase_web_api_key) < 20:
            raise RuntimeError("FIREBASE_WEB_API_KEY is required.")
        if len(self.dashboard_session_secret) < 32:
            raise RuntimeError(
                "DASHBOARD_SESSION_SECRET must contain at least 32 characters."
            )


@lru_cache
def get_settings() -> Settings:
    return Settings()
