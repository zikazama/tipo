"""Local media files, with a Cloud Storage hook when TIPO_GCS_BUCKET is set."""

from __future__ import annotations

import base64
import binascii
from pathlib import Path
from typing import Any

from PIL import Image, ExifTags

from app.config import Settings


def read_exif(image_bytes: bytes) -> dict[str, Any]:
    try:
        image = Image.open(__import__("io").BytesIO(image_bytes))
        raw = image.getexif()
    except Exception:
        return {}
    if not raw:
        return {}
    mapped = {ExifTags.TAGS.get(k, str(k)): v for k, v in raw.items()}
    out: dict[str, Any] = {}
    taken = mapped.get("DateTimeOriginal") or mapped.get("DateTime")
    if isinstance(taken, str):
        # EXIF uses "YYYY:MM:DD HH:MM:SS"
        out["taken_at"] = taken.replace(":", "-", 2)
    gps = raw.get_ifd(ExifTags.IFD.GPSInfo) if hasattr(raw, "get_ifd") else {}
    if gps:
        parsed = _gps(gps)
        out.update(parsed)
    return out


def _ratio(value: Any) -> float:
    try:
        return float(value)
    except TypeError:
        return float(value[0]) / float(value[1] or 1)


def _gps(gps: dict) -> dict[str, float]:
    def coord(values, ref: str) -> float | None:
        if not values or len(values) < 3:
            return None
        degrees = _ratio(values[0]) + _ratio(values[1]) / 60 + _ratio(values[2]) / 3600
        if ref in {"S", "W"}:
            degrees *= -1
        return degrees

    lat = coord(gps.get(2), str(gps.get(1) or ""))
    lng = coord(gps.get(4), str(gps.get(3) or ""))
    out = {}
    if lat is not None:
        out["lat"] = lat
    if lng is not None:
        out["lng"] = lng
    return out


class MediaStore:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.root = settings.data_dir / "uploads"
        self.root.mkdir(parents=True, exist_ok=True)
        self.bucket = None
        if settings.gcs_bucket:
            try:
                from google.cloud import storage

                self.bucket = storage.Client().bucket(settings.gcs_bucket)
            except Exception:
                self.bucket = None

    def save_base64(self, report_id: str, kind: str, payload: str) -> str:
        if "," in payload and payload.strip().startswith("data:"):
            payload = payload.split(",", 1)[1]
        try:
            blob = base64.b64decode(payload, validate=False)
        except binascii.Error as exc:
            raise ValueError("Media payload is not valid base64") from exc
        ext = "jpg" if kind == "photo" else "wav"
        name = f"{report_id}-{kind}.{ext}"
        path = self.root / name
        path.write_bytes(blob)
        if self.bucket is not None:
            self.bucket.blob(f"reports/{name}").upload_from_filename(str(path))
        return name

    def resolve(self, name: str, scenario_dir: Path) -> Path | None:
        safe = Path(name).name
        for folder in (self.root, scenario_dir):
            candidate = folder / safe
            if candidate.is_file():
                return candidate
        return None
