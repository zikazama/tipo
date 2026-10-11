"""HTTP API for the citizen app and the operator dashboard."""

from __future__ import annotations

from typing import Any

import httpx
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import PlainTextResponse, Response
from pydantic import BaseModel, Field

from app.bmkg import bmkg_catalog

router = APIRouter()


class ReportIn(BaseModel):
    id: str | None = None
    channel: str = "app"
    reporter_id: str = "anonymous"
    text: str = ""
    transcript: str | None = None
    translation_en: str | None = None
    language: str | None = None
    hazard_hint: str | None = None
    lat: float
    lng: float
    place_name: str | None = None
    photo_base64: str | None = None
    audio_base64: str | None = None
    photo_file: str | None = None
    audio_file: str | None = None
    exif: dict[str, Any] | None = None
    image_cues: list[str] = Field(default_factory=list)
    simulated: bool = False
    delay_s: float | None = None


class PresenceIn(BaseModel):
    reporter_id: str
    lat: float
    lng: float
    label: str | None = None


class DecisionIn(BaseModel):
    action: str
    operator_name: str = "Posko operator"
    note: str = ""
    priority_band: str | None = None
    people_affected: int | None = None
    needs: list[str] | None = None
    team_id: str | None = None
    send_alert: bool = False


def _pipeline(request: Request):
    return request.app.state.pipeline


@router.get("/api/health")
def health(request: Request) -> dict[str, Any]:
    settings = request.app.state.settings
    return {
        "status": "ok",
        "service": "tipo",
        "mode": settings.mode,
        "live_credentials": settings.live_credentials,
        "store": "firestore" if settings.use_firestore else "memory",
        "fcm": settings.fcm_enabled,
        "models": {
            "main": settings.model_main,
            "lite": settings.model_lite,
            "transcribe": settings.model_transcribe,
            "embed": settings.model_embed,
        },
    }


@router.get("/api/meta")
def meta(request: Request) -> dict[str, Any]:
    info = health(request)
    scenario = request.app.state.pipeline.scenario
    info["scenario"] = {
        "id": scenario.get("id"),
        "title": scenario.get("title"),
        "reports": len(scenario.get("reports") or []),
        "tagline": "Read the signs. Act first.",
        "place": "Dayeuhkolot, Kabupaten Bandung",
    }
    info["replay"] = request.app.state.replay.status()
    return info


@router.get("/api/state")
def state(request: Request) -> dict[str, Any]:
    snap = request.app.state.store.snapshot()
    incidents = []
    for inc in snap["incidents"]:
        data = dict(inc)
        data.pop("embedding", None)
        data.pop("embed_text", None)
        incidents.append(data)
    incidents.sort(key=lambda item: item.get("priority_score") or 0, reverse=True)
    return {
        "meta": meta(request),
        "replay": request.app.state.replay.status(),
        "incidents": incidents,
        "reports": snap["reports"],
        "notifications": snap["notifications"],
        "presence": snap["presence"],
        "resources": snap["resources"],
    }


@router.post("/api/reports")
def create_report(body: ReportIn, request: Request) -> dict[str, Any]:
    if not body.text and not body.transcript and not body.photo_base64 and not body.audio_base64 and not body.photo_file:
        raise HTTPException(status_code=422, detail="Add text, a voice note, or a photo before sending.")
    if not (-90 <= body.lat <= 90 and -180 <= body.lng <= 180):
        raise HTTPException(status_code=422, detail="Latitude or longitude is out of range.")
    try:
        result = _pipeline(request).ingest(body.model_dump())
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return result


@router.get("/api/reports")
def list_reports(request: Request, reporter_id: str | None = None) -> dict[str, Any]:
    reports = request.app.state.store.snapshot()["reports"]
    if reporter_id:
        reports = [r for r in reports if r.get("reporter_id") == reporter_id]
    reports = sorted(reports, key=lambda r: r.get("created_at") or "", reverse=True)
    return {"reports": reports}


@router.get("/api/reports/{report_id}")
def get_report(report_id: str, request: Request) -> dict[str, Any]:
    report = request.app.state.store.reports.get(report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found.")
    return report


@router.get("/api/incidents")
def list_incidents(request: Request) -> dict[str, Any]:
    incidents = []
    for inc in request.app.state.store.incidents.values():
        data = dict(inc)
        data.pop("embedding", None)
        data.pop("embed_text", None)
        incidents.append(data)
    incidents.sort(key=lambda item: item.get("priority_score") or 0, reverse=True)
    return {"incidents": incidents}


@router.get("/api/incidents/{incident_id}")
def get_incident(incident_id: str, request: Request) -> dict[str, Any]:
    inc = request.app.state.store.incidents.get(incident_id)
    if not inc:
        raise HTTPException(status_code=404, detail="Incident not found.")
    data = dict(inc)
    data.pop("embedding", None)
    data.pop("embed_text", None)
    data["reports"] = [
        request.app.state.store.reports[rid]
        for rid in data.get("report_ids") or []
        if rid in request.app.state.store.reports
    ]
    return data


@router.post("/api/incidents/{incident_id}/decision")
def decide(incident_id: str, body: DecisionIn, request: Request) -> dict[str, Any]:
    if body.priority_band and body.priority_band not in {"critical", "high", "medium", "low"}:
        raise HTTPException(status_code=422, detail="priority_band must be critical, high, medium, or low.")
    try:
        return _pipeline(request).decide(incident_id, body.model_dump())
    except KeyError:
        raise HTTPException(status_code=404, detail="Incident not found.") from None
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.get("/api/incidents/{incident_id}/sitrep", response_class=PlainTextResponse)
def sitrep(incident_id: str, request: Request) -> PlainTextResponse:
    inc = request.app.state.store.incidents.get(incident_id)
    if not inc:
        raise HTTPException(status_code=404, detail="Incident not found.")
    text = inc.get("sitrep_markdown") or ""
    return PlainTextResponse(
        text,
        media_type="text/markdown; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{incident_id}-sitrep.md"'},
    )


@router.post("/api/presence")
def presence(body: PresenceIn, request: Request) -> dict[str, Any]:
    item = body.model_dump()
    request.app.state.store.set_presence(item)
    return item


@router.get("/api/notifications")
def notifications(
    request: Request,
    reporter_id: str | None = None,
    type: str | None = None,
) -> dict[str, Any]:
    items = request.app.state.store.snapshot()["notifications"]
    if reporter_id:
        items = [n for n in items if n.get("reporter_id") == reporter_id]
    if type:
        items = [n for n in items if n.get("type") == type]
    return {"notifications": items}


@router.post("/api/replay")
async def replay(request: Request, wait: bool = False) -> dict[str, Any]:
    engine = request.app.state.replay
    if wait:
        return await engine.run()
    engine.kick()
    return engine.status() | {"started": True}


@router.post("/api/replay/reset")
def replay_reset(request: Request) -> dict[str, Any]:
    engine = request.app.state.replay
    if engine._task and not engine._task.done():
        engine._task.cancel()
    engine.running = False
    engine.ingested = 0
    request.app.state.pipeline.reset()
    return engine.status()


@router.get("/api/samples")
def samples(request: Request) -> dict[str, Any]:
    return {"samples": request.app.state.pipeline.scenario.get("samples") or []}


@router.get("/api/resources")
def resources(request: Request) -> dict[str, Any]:
    return request.app.state.store.resources


@router.get("/api/petabencana")
def petabencana(live: bool = False) -> dict[str, Any]:
    endpoint = "https://data.petabencana.id/reports"
    if not live:
        return {
            "ok": True,
            "live": False,
            "endpoint": endpoint,
            "note": "The replay already includes seeded PetaBencana-channel reports. Live ingest is a read-only check.",
        }
    try:
        with httpx.Client(timeout=8.0, headers={"User-Agent": "tipo-posko/0.1"}) as client:
            response = client.get(endpoint, params={"timeperiod": "86400"})
            response.raise_for_status()
            payload = response.json()
    except Exception as exc:
        return {"ok": False, "live": True, "endpoint": endpoint, "error": str(exc)}
    count = None
    if isinstance(payload, dict):
        objects = payload.get("objects") or {}
        if isinstance(objects, dict):
            for value in objects.values():
                geoms = value.get("geometries") if isinstance(value, dict) else None
                if isinstance(geoms, list):
                    count = len(geoms)
                    break
        result = payload.get("result")
        if count is None and isinstance(result, list):
            count = len(result)
    return {"ok": True, "live": True, "endpoint": endpoint, "feature_count": count}


@router.get("/api/bmkg")
def bmkg(request: Request, live: bool = False) -> dict[str, Any]:
    recorded = request.app.state.pipeline.scenario.get("bmkg") or {}
    if not live:
        return {"recorded": recorded}
    return bmkg_catalog()


@router.get("/media/{name}")
def media(name: str, request: Request) -> Response:
    path = request.app.state.media.resolve(name, request.app.state.settings.media_dir)
    if path is None:
        raise HTTPException(status_code=404, detail="Media not found.")
    kind = "image/png" if path.suffix == ".png" else "audio/wav" if path.suffix == ".wav" else "application/octet-stream"
    if path.suffix in {".jpg", ".jpeg"}:
        kind = "image/jpeg"
    return Response(content=path.read_bytes(), media_type=kind)
