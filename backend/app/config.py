"""Runtime configuration. Defaults to mock mode so the demo runs with no secrets."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


def _flag(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


@dataclass(frozen=True)
class Settings:
    mode: str
    model_main: str
    model_lite: str
    model_transcribe: str
    model_embed: str
    replay_speed: float
    data_dir: Path
    scenario_path: Path
    media_dir: Path
    gcs_bucket: str
    firestore_project: str
    google_cloud_location: str
    nearby_radius_m: float
    port: int

    @property
    def live_credentials(self) -> bool:
        if _flag("GOOGLE_API_KEY") or _flag("GEMINI_API_KEY"):
            return True
        vertex = _flag("GOOGLE_GENAI_USE_VERTEXAI").lower() in {"1", "true", "yes"}
        return vertex and bool(_flag("GOOGLE_CLOUD_PROJECT"))

    @property
    def use_firestore(self) -> bool:
        return _flag("TIPO_STORE").lower() == "firestore" and bool(self.firestore_project)

    @property
    def fcm_enabled(self) -> bool:
        return _flag("TIPO_FCM").lower() in {"1", "true", "yes"} and bool(
            _flag("FIREBASE_SERVICE_ACCOUNT_JSON") or _flag("GOOGLE_APPLICATION_CREDENTIALS")
        )


def load_settings() -> Settings:
    mode = _flag("TIPO_MODE", "mock").lower()
    if mode not in {"mock", "live"}:
        mode = "mock"
    data_dir = Path(_flag("TIPO_DATA_DIR", str(REPO_ROOT / "backend" / "data"))).resolve()
    scenario = Path(
        _flag("TIPO_SCENARIO", str(REPO_ROOT / "scenario" / "dayeuhkolot_flood.json"))
    ).resolve()
    try:
        speed = float(_flag("TIPO_REPLAY_SPEED", "1"))
    except ValueError:
        speed = 1.0
    return Settings(
        mode=mode,
        model_main=_flag("TIPO_MODEL_MAIN", "gemini-3.8-flash"),
        model_lite=_flag("TIPO_MODEL_LITE", "gemini-3.5-flash-lite"),
        model_transcribe=_flag("TIPO_MODEL_TRANSCRIBE", "gemini-3.5-transcribe"),
        model_embed=_flag("TIPO_MODEL_EMBED", "gemini-embedding-2-preview"),
        replay_speed=speed,
        data_dir=data_dir,
        scenario_path=scenario,
        media_dir=Path(_flag("TIPO_MEDIA_DIR", str(REPO_ROOT / "scenario" / "media"))).resolve(),
        gcs_bucket=_flag("TIPO_GCS_BUCKET"),
        firestore_project=_flag("GOOGLE_CLOUD_PROJECT") or _flag("TIPO_FIRESTORE_PROJECT"),
        google_cloud_location=_flag("GOOGLE_CLOUD_LOCATION", "asia-southeast2"),
        nearby_radius_m=float(_flag("TIPO_NEARBY_RADIUS_M", "2000") or "2000"),
        port=int(_flag("PORT", "8765") or "8765"),
    )
