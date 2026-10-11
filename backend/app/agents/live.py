"""Live Gemini pass through the ADK sequential agent.

Deterministic agents stay authoritative for clustering so a replay cannot fork.
When credentials exist, Gemini may rewrite the English translation, the incident
summary, and add a verification note. Any failure keeps the mock result and
labels the trace live_fallback.
"""

from __future__ import annotations

import json
import os
from typing import Any

from app.agents.adk_pipeline import build_pipeline
from app.agents.prompts import PIPELINE
from app.config import Settings


def _extract_json(text: str) -> dict[str, Any] | None:
    if not text:
        return None
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        return None
    try:
        data = json.loads(text[start : end + 1])
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


async def run_adk_text(settings: Settings, prompt: str) -> str:
    """Execute the ADK pipeline once and return the final model text."""
    from google.adk.runners import InMemoryRunner
    from google.genai import types

    if settings.live_credentials and os.getenv("GOOGLE_GENAI_USE_VERTEXAI", "").lower() in {"1", "true", "yes"}:
        os.environ.setdefault("GOOGLE_CLOUD_LOCATION", settings.google_cloud_location)
    root = build_pipeline(settings)
    runner = InMemoryRunner(agent=root, app_name="tipo")
    session = await runner.session_service.create_session(app_name="tipo", user_id="posko")
    message = types.Content(role="user", parts=[types.Part(text=prompt)])
    final = ""
    async for event in runner.run_async(user_id="posko", session_id=session.id, new_message=message):
        if event.is_final_response() and event.content and event.content.parts:
            part = event.content.parts[0]
            final = getattr(part, "text", None) or final
    state = await runner.session_service.get_session(app_name="tipo", user_id="posko", session_id=session.id)
    if state and state.state:
        # Prefer the triage agent's structured slot when ADK stored it.
        for key in ("triage_json", "verification_json", "intake_json"):
            slot = state.state.get(key)
            if isinstance(slot, dict):
                return json.dumps(slot)
            if isinstance(slot, str) and slot.strip():
                return slot
    return final


def review_prompt(report: dict[str, Any], intake: dict[str, Any], verification: dict[str, Any]) -> str:
    return "\n".join(
        [
            PIPELINE.strip(),
            "Review this citizen report. The deterministic baseline is evidence, not an order.",
            "Return ONLY JSON with optional keys translation_en, summary, verification_note.",
            "Do not claim an alert was sent.",
            "REPORT:",
            json.dumps(
                {
                    "text": report.get("text"),
                    "transcript": report.get("transcript"),
                    "channel": report.get("channel"),
                    "lat": report.get("lat"),
                    "lng": report.get("lng"),
                    "exif": report.get("exif"),
                    "image_cues": report.get("image_cues"),
                },
                ensure_ascii=False,
            ),
            "BASELINE_INTAKE:",
            json.dumps(intake, ensure_ascii=False),
            "BASELINE_VERIFICATION:",
            json.dumps({k: verification[k] for k in ("credibility", "reasons") if k in verification}, ensure_ascii=False),
        ]
    )


async def maybe_review(
    settings: Settings,
    report: dict[str, Any],
    intake: dict[str, Any],
    verification: dict[str, Any],
) -> dict[str, Any]:
    if settings.mode != "live":
        return {"mode": "mock"}
    if not settings.live_credentials:
        return {"mode": "live_fallback", "reason": "Set GOOGLE_API_KEY or Vertex AI env vars to call Gemini."}
    try:
        text = await run_adk_text(settings, review_prompt(report, intake, verification))
    except Exception as exc:
        return {"mode": "live_fallback", "reason": f"Gemini call failed: {exc}"}
    parsed = _extract_json(text) or {}
    if not parsed and text:
        return {"mode": "live_fallback", "reason": "Gemini answered without JSON. Baseline kept.", "raw": text[:500]}
    return {"mode": "live", "review": parsed}


def apply_review(intake: dict[str, Any], verification: dict[str, Any], review: dict[str, Any]) -> None:
    mode = review.get("mode") or "mock"
    intake["mode"] = mode
    verification["mode"] = mode
    data = review.get("review") or {}
    if data.get("translation_en"):
        intake["translation_en"] = str(data["translation_en"]).strip()
    if data.get("summary"):
        intake["summary"] = str(data["summary"]).strip()
    note = data.get("verification_note")
    if note:
        verification["reasons"] = list(verification.get("reasons") or []) + [f"Gemini review: {note}"]
    if review.get("reason") and mode == "live_fallback":
        verification["reasons"] = list(verification.get("reasons") or []) + [f"Live mode fallback: {review['reason']}"]
