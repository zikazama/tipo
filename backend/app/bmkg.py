"""BMKG open-data tools.

Replay and unit tests read the recorded scenario snapshot so a dry live forecast
cannot flip the Dayeuhkolot drill. Live mode also tries the public endpoints and
records whichever source answered.
"""

from __future__ import annotations

import json
from typing import Any
from xml.etree import ElementTree

import httpx

from app.config import Settings, load_settings

FORECAST_URL = "https://api.bmkg.go.id/publik/prakiraan-cuaca"
QUAKE_AUTO = "https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json"
QUAKE_RECENT = "https://data.bmkg.go.id/DataMKG/TEWS/gempaterkini.json"
NOWCAST_RSS = "https://www.bmkg.go.id/alerts/nowcast/id/rss.xml"

_SNAPSHOT: dict[str, Any] | None = None


def bind_snapshot(snapshot: dict[str, Any]) -> None:
    global _SNAPSHOT
    _SNAPSHOT = snapshot


def snapshot() -> dict[str, Any]:
    if _SNAPSHOT is None:
        settings = load_settings()
        data = json.loads(settings.scenario_path.read_text(encoding="utf-8"))
        bind_snapshot(data.get("bmkg") or {})
    return _SNAPSHOT or {}


def area_for(place_key: str) -> dict[str, Any]:
    areas = snapshot().get("areas") or {}
    return dict(areas.get(place_key) or areas.get("dayeuhkolot") or {})


def earthquake_snapshot() -> dict[str, Any]:
    return dict(snapshot().get("earthquake") or {})


def _client() -> httpx.Client:
    return httpx.Client(timeout=8.0, headers={"User-Agent": "tipo-posko/0.1 (hackathon prototype)"})


def fetch_forecast_live(adm4: str) -> dict[str, Any] | None:
    try:
        with _client() as client:
            response = client.get(FORECAST_URL, params={"adm4": adm4})
            response.raise_for_status()
            payload = response.json()
    except (httpx.HTTPError, json.JSONDecodeError, ValueError):
        return None
    lokasi = payload.get("lokasi") or {}
    first = None
    try:
        first = payload["data"][0]["cuaca"][0][0]
    except (KeyError, IndexError, TypeError):
        first = None
    if not first:
        return None
    return {
        "adm4": adm4,
        "name": f"{lokasi.get('desa', '')}, {lokasi.get('kecamatan', '')}, {lokasi.get('kotkab', '')}".strip(", "),
        "weather_desc_en": first.get("weather_desc_en") or first.get("weather_desc"),
        "tp_mm": first.get("tp") or 0,
        "period": "3h",
        "source": "bmkg_live_forecast",
    }


def fetch_quake_live() -> dict[str, Any] | None:
    try:
        with _client() as client:
            response = client.get(QUAKE_AUTO)
            response.raise_for_status()
            gempa = response.json()["Infogempa"]["gempa"]
    except (httpx.HTTPError, KeyError, json.JSONDecodeError, ValueError):
        return None
    coords = str(gempa.get("Coordinates") or "0,0").split(",")
    try:
        lat, lng = float(coords[0]), float(coords[1])
    except (ValueError, IndexError):
        lat, lng = 0.0, 0.0
    return {
        "source": QUAKE_AUTO,
        "magnitude": gempa.get("Magnitude"),
        "place": gempa.get("Wilayah"),
        "coordinates": [lat, lng],
        "time_wib": f"{gempa.get('Tanggal', '')} {gempa.get('Jam', '')}".strip(),
    }


def fetch_nowcast_live(limit: int = 5) -> list[dict[str, str]]:
    try:
        with _client() as client:
            response = client.get(NOWCAST_RSS)
            response.raise_for_status()
            root = ElementTree.fromstring(response.text)
    except (httpx.HTTPError, ElementTree.ParseError):
        return []
    items = []
    for item in root.iter("item"):
        title = (item.findtext("title") or "").strip()
        link = (item.findtext("link") or "").strip()
        if title:
            items.append({"title": title, "link": link})
        if len(items) >= limit:
            break
    return items


def bmkg_forecast(adm4: str) -> dict[str, Any]:
    """Forecast for a BPS adm4 code. Uses the live BMKG API, then the recorded snapshot.

    Args:
        adm4: Kelurahan/desa code, for example 32.04.12.2002 for Desa Dayeuhkolot.
    """
    settings = load_settings()
    if settings.mode == "live":
        live = fetch_forecast_live(adm4)
        if live:
            return live
    for area in (snapshot().get("areas") or {}).values():
        if str(area.get("adm4")) == str(adm4):
            found = dict(area)
            found["source"] = found.get("source") or "scenario_snapshot"
            return found
    fallback = dict(area_for("dayeuhkolot"))
    fallback["note"] = f"No area matched adm4 {adm4}; returning the Dayeuhkolot scenario snapshot."
    return fallback


def bmkg_earthquakes() -> dict[str, Any]:
    """Latest BMKG earthquake from autogempa, with the recorded snapshot as fallback."""
    settings = load_settings()
    if settings.mode == "live":
        live = fetch_quake_live()
        if live:
            return live
    data = earthquake_snapshot()
    data.setdefault("source", QUAKE_AUTO)
    return data


def bmkg_nowcast() -> dict[str, Any]:
    """Headlines from the BMKG nowcast RSS. Replay does not depend on the live feed."""
    settings = load_settings()
    if settings.mode == "live":
        items = fetch_nowcast_live()
        if items:
            return {"source": NOWCAST_RSS, "items": items}
    return {
        "source": "scenario_snapshot",
        "items": snapshot().get("nowcast") or [],
        "note": "Live nowcast was not required for this response.",
    }


def bmkg_catalog() -> dict[str, Any]:
    """Operator-facing view: recorded snapshot plus a best-effort live sample."""
    recorded = snapshot()
    live: dict[str, Any] = {"forecast": None, "earthquake": None, "nowcast": []}
    # One live sample for the dashboard drawer. Failures stay visible, not fatal.
    sample_adm4 = ((recorded.get("areas") or {}).get("dayeuhkolot") or {}).get("adm4") or "32.04.12.2002"
    live["forecast"] = fetch_forecast_live(str(sample_adm4))
    live["earthquake"] = fetch_quake_live()
    live["nowcast"] = fetch_nowcast_live(3)
    return {"recorded": recorded, "live": live, "endpoints": {
        "forecast": FORECAST_URL,
        "autogempa": QUAKE_AUTO,
        "gempaterkini": QUAKE_RECENT,
        "nowcast": NOWCAST_RSS,
    }}
