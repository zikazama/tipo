"""Dedup agent: merge reports that describe one incident, keep hoaxes aside."""

from __future__ import annotations

import hashlib
import math
from typing import Any

from app.config import Settings
from app.geo import haversine_m
from app.lexicon import tokens

STOP = {
    "yang", "dan", "di", "ke", "dari", "the", "a", "of", "in", "on", "ada", "ya", "ini", "itu",
    "dengan", "untuk", "sudah", "udah", "geus", "wis", "ana", "aya", "sing",
}


def token_embedding(text: str, dims: int = 64) -> list[float]:
    """Deterministic stand-in for gemini-embedding-2-preview.

    Live mode replaces this vector when the embedding API answers. Tests use this
    function so cosine similarity is stable offline.
    """
    vec = [0.0] * dims
    for tok in tokens(text):
        if tok in STOP or len(tok) < 3 or tok.isdigit():
            continue
        digest = hashlib.sha256(tok.encode()).digest()
        idx = digest[0] % dims
        sign = 1.0 if digest[1] % 2 == 0 else -1.0
        vec[idx] += sign
    norm = math.sqrt(sum(v * v for v in vec)) or 1.0
    return [v / norm for v in vec]


def cosine(a: list[float], b: list[float]) -> float:
    if not a or not b or len(a) != len(b):
        return 0.0
    return float(sum(x * y for x, y in zip(a, b)))


def run_dedup(
    report: dict[str, Any],
    intake: dict[str, Any],
    verification: dict[str, Any],
    incidents: list[dict[str, Any]],
    settings: Settings,
    embedding: list[float] | None = None,
    mode: str = "mock",
) -> dict[str, Any]:
    text = intake.get("transcript") or ""
    vector = embedding or token_embedding(text)
    hazard = intake.get("hazard_type")
    key = intake.get("place_key")
    cred = int(verification.get("credibility") or 0)
    best: dict[str, Any] | None = None
    best_sim = 0.0
    if hazard == "other":
        followups = []
        for inc in incidents:
            if inc.get("status") == "rejected" or inc.get("cluster_key") != key or key == "unknown":
                continue
            dist = haversine_m(float(report["lat"]), float(report["lng"]), float(inc["lat"]), float(inc["lng"]))
            if dist > 2500:
                continue
            inc_cred = int(inc.get("credibility") or 0)
            if cred < 40 and inc_cred >= 40:
                continue
            if cred >= 40 and inc_cred < 40:
                continue
            followups.append(inc)
        if followups:
            followups.sort(key=lambda inc: int(inc.get("priority_score") or inc.get("credibility") or 0), reverse=True)
            chosen = followups[0]
            return {
                "agent": "dedup",
                "mode": mode,
                "model": settings.model_lite,
                "embedding_model": settings.model_embed + " (mock token embedding)",
                "action": "merge",
                "incident_id": chosen["id"],
                "similarity": 0.0,
                "embedding": vector,
                "reason": (
                    f"Follow-up without a new hazard type. Attached to {chosen['id']} "
                    f"because it is the open {chosen.get('hazard_type')} incident at this place."
                ),
            }
    for inc in incidents:
        if inc.get("status") == "rejected":
            continue
        if inc.get("hazard_type") != hazard:
            continue
        dist = haversine_m(float(report["lat"]), float(report["lng"]), float(inc["lat"]), float(inc["lng"]))
        if dist > 2500:
            continue
        same_place = inc.get("cluster_key") == key and key != "unknown"
        sim = cosine(vector, inc.get("embedding") or token_embedding(inc.get("embed_text") or ""))
        if not same_place and sim < 0.72 and dist > 800:
            continue
        inc_cred = int(inc.get("credibility") or 0)
        # Low-credibility claims must not contaminate a corroborated incident.
        if cred < 40 and inc_cred >= 40:
            continue
        if cred >= 40 and inc_cred < 40:
            continue
        if best is None or sim > best_sim:
            best = inc
            best_sim = sim
    model_name = settings.model_embed
    if best is None:
        reason = (
            "No compatible open incident within 2.5 km. "
            + (
                "Credibility is under 40, so this report is held as its own unconfirmed incident."
                if cred < 40
                else "Opening a new incident."
            )
        )
        return {
            "agent": "dedup",
            "mode": mode,
            "model": settings.model_lite,
            "embedding_model": model_name if embedding else f"{model_name} (mock token embedding)",
            "action": "new",
            "incident_id": None,
            "similarity": round(best_sim, 3),
            "embedding": vector,
            "reason": reason,
        }
    return {
        "agent": "dedup",
        "mode": mode,
        "model": settings.model_lite,
        "embedding_model": model_name if embedding else f"{model_name} (mock token embedding)",
        "action": "merge",
        "incident_id": best["id"],
        "similarity": round(best_sim, 3),
        "embedding": vector,
        "reason": (
            f"Same hazard and place as {best['id']} "
            f"({best.get('title', 'open incident')}). Embedding similarity {best_sim:.2f}. "
            "Merging into that incident instead of opening a duplicate ticket."
        ),
    }
