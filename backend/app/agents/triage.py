"""Triage agent: priority, logistics, team suggestion, BNPB-style sitrep draft."""

from __future__ import annotations

import math
from datetime import datetime, timezone
from typing import Any
from zoneinfo import ZoneInfo

from app.config import Settings
from app.geo import clamp, haversine_m

WIB = ZoneInfo("Asia/Jakarta")
BANDS = (("critical", 80), ("high", 60), ("medium", 40), ("low", 0))


def band_for(score: int) -> str:
    for name, floor in BANDS:
        if score >= floor:
            return name
    return "low"


def priority_score(
    severity: int,
    people: int,
    vulnerable: list[str],
    credibility: int,
    needs: list[str],
    trapped: int,
) -> tuple[int, bool]:
    sev = max(1, min(5, int(severity))) / 5
    people_f = min(max(int(people), 0) / 150, 1)
    vuln_f = 1.0 if any(v in {"elderly", "infants", "disability", "pregnant"} for v in vulnerable) else 0.0
    if trapped >= 5:
        vuln_f = 1.0
    cred_f = max(0, min(100, int(credibility))) / 100
    urgent = 1.0 if any(n in needs for n in ("evacuation", "boat", "medicine")) else 0.35
    raw = 100 * (0.34 * sev + 0.24 * people_f + 0.16 * vuln_f + 0.18 * cred_f + 0.08 * urgent)
    capped = credibility < 40
    if capped:
        raw *= 0.45
    return int(round(clamp(raw, 1, 99))), capped


def _eta(dist_m: float, kind: str) -> int:
    speed = {"boat": 18, "medical": 28, "logistics": 32}.get(kind, 24)
    minutes = dist_m / 1000 / speed * 60 + 8
    return max(10, int(round(minutes)))


def _pick_team(kind: str, lat: float, lng: float, teams: list[dict], skip: str | None = None) -> dict | None:
    pool = [t for t in teams if t.get("kind") == kind and t.get("id") != skip]
    if not pool:
        pool = [t for t in teams if t.get("id") != skip]
    if not pool:
        return None
    # Boats parked at the same posko share a 200 m bucket; the lower id is the primary call.
    pool.sort(key=lambda t: (int(haversine_m(lat, lng, float(t["lat"]), float(t["lng"])) // 200), t["id"]))
    team = pool[0]
    dist = haversine_m(lat, lng, float(team["lat"]), float(team["lng"]))
    return {
        "id": team["id"],
        "name": team["name"],
        "kind": team.get("kind"),
        "posko": team.get("posko"),
        "eta_min": _eta(dist, team.get("kind") or "logistics"),
        "distance_m": int(dist),
    }


def _pick_shelter(lat: float, lng: float, shelters: list[dict]) -> dict | None:
    if not shelters:
        return None
    ranked = sorted(shelters, key=lambda s: haversine_m(lat, lng, float(s["lat"]), float(s["lng"])))
    shelter = ranked[0]
    dist = haversine_m(lat, lng, float(shelter["lat"]), float(shelter["lng"]))
    free = int(shelter.get("capacity", 0)) - int(shelter.get("occupied", 0))
    return {
        "id": shelter["id"],
        "name": shelter["name"],
        "distance_m": int(dist),
        "beds_free": max(0, free),
        "capacity": shelter.get("capacity"),
    }


def render_sitrep(incident: dict[str, Any], logistics: dict, team: dict | None, shelter: dict | None) -> str:
    when = incident.get("updated_at") or datetime.now(timezone.utc).isoformat()
    try:
        dt = datetime.fromisoformat(when.replace("Z", "+00:00")).astimezone(WIB)
        stamp = dt.strftime("%d %b %Y, %H:%M WIB")
    except ValueError:
        stamp = when
    vuln = ", ".join(incident.get("vulnerable") or []) or "none recorded"
    needs = ", ".join(incident.get("needs") or []) or "not specified"
    channels = ", ".join(incident.get("channels") or []) or "app"
    team_line = (
        f"Suggest {team['name']} from {team['posko']} (about {team['eta_min']} min, {team['distance_m']} m)."
        if team
        else "No seeded team is available."
    )
    shelter_line = (
        f"Nearest shelter: {shelter['name']} ({shelter['beds_free']} beds free, {shelter['distance_m']} m)."
        if shelter
        else "No seeded shelter."
    )
    decision = incident.get("decision")
    if decision and decision.get("action") == "approve":
        handling = (
            f"Operator {decision.get('operator_name', 'operator')} approved this draft"
            f"{' and released a nearby alert' if decision.get('alert_sent') else ' without a public alert'}."
        )
    elif decision and decision.get("action") == "reject":
        handling = f"Operator {decision.get('operator_name', 'operator')} rejected this incident. No public alert."
    else:
        handling = "Waiting for a human operator. TIPO has not sent an alert."
    reasons = incident.get("priority_reasons") or []
    reason_block = "\n".join(f"- {r}" for r in reasons) or "- Priority follows the triage formula."
    return "\n".join(
        [
            "# SITUATION REPORT (draft)",
            "## BNPB-style brief prepared by TIPO",
            "",
            "This is an operator draft, not an official BNPB release.",
            "",
            f"- **Event:** {str(incident.get('hazard_type', 'hazard')).replace('_', ' ').title()}",
            f"- **Location:** {incident.get('place_label')}",
            f"- **Coordinates:** {incident.get('lat'):.5f}, {incident.get('lng'):.5f}",
            f"- **Updated:** {stamp}",
            f"- **Ticket:** {incident.get('id')}",
            f"- **Status:** {incident.get('status', 'open')}",
            "",
            "### What happened",
            incident.get("summary") or "Citizen reports are still being read.",
            "",
            "### Impact",
            f"- People affected (highest consistent claim): {incident.get('people_affected') or 0}",
            f"- People described as trapped: {incident.get('trapped') or 0}",
            f"- Vulnerable groups: {vuln}",
            f"- Citizen requests: {needs}",
            f"- Credibility: {incident.get('credibility')}/100",
            f"- Priority: {incident.get('priority_score')} ({incident.get('priority_band')})",
            "",
            "### Why this priority",
            reason_block,
            "",
            "### Urgent logistics estimate",
            f"- Drinking water: {logistics['water_liters_per_day']} L/day (3 L per person)",
            f"- Ready meals: {logistics['ready_meals']} (2 per person)",
            f"- Boats: {logistics['boats']}",
            f"- Family kits: {logistics['family_kits']}",
            "",
            "### Suggested assignment",
            team_line,
            shelter_line,
            "",
            "### Handling",
            handling,
            "",
            "### Sources",
            f"- Citizen reports merged: {len(incident.get('report_ids') or [])} across {channels}",
            "- BMKG forecast / earthquake open data (scenario snapshot in replay; live tool when configured)",
            "- Seeded posko teams and shelters",
            "",
            "A human operator must approve this draft before any warning is sent to citizens.",
        ]
    )


def run_triage(
    incident: dict[str, Any],
    resources: dict[str, Any],
    settings: Settings,
    mode: str = "mock",
) -> dict[str, Any]:
    people = int(incident.get("people_affected") or 0)
    trapped = int(incident.get("trapped") or 0)
    needs = list(incident.get("needs") or [])
    score, capped = priority_score(
        int(incident.get("severity") or 2),
        people,
        list(incident.get("vulnerable") or []),
        int(incident.get("credibility") or 0),
        needs,
        trapped,
    )
    priority_band = band_for(score)
    boats = 0
    if incident.get("hazard_type") == "flood" and ("boat" in needs or "evacuation" in needs or trapped):
        boats = max(1, math.ceil(trapped / 6)) if trapped else 1
    logistics = {
        "water_liters_per_day": people * 3,
        "ready_meals": people * 2,
        "boats": boats,
        "family_kits": math.ceil(people / 4) if people else 0,
    }
    kind = "boat" if boats else "medical" if "medicine" in needs else "logistics"
    team = _pick_team(kind, float(incident["lat"]), float(incident["lng"]), resources.get("teams") or [])
    standby = None
    if boats >= 2 and team:
        standby = _pick_team("boat", float(incident["lat"]), float(incident["lng"]), resources.get("teams") or [], skip=team["id"])
    shelter = _pick_shelter(float(incident["lat"]), float(incident["lng"]), resources.get("shelters") or [])
    reasons = [
        f"Severity {incident.get('severity')}/5, {people} people in the merged claim, credibility {incident.get('credibility')}/100.",
    ]
    if incident.get("vulnerable"):
        reasons.append("Vulnerable groups mentioned: " + ", ".join(incident["vulnerable"]) + ".")
    if trapped:
        reasons.append(f"{trapped} people are described as trapped, so the boat estimate is {boats}.")
    if capped:
        reasons.append("Priority is capped because credibility is under 40. Do not treat this as a confirmed disaster.")
    elif priority_band in {"critical", "high"}:
        reasons.append("Score is in the dispatch range. Still waiting for an operator before any alert.")
    else:
        reasons.append("Impact looks limited, so this stays below the dispatch range unless an operator upgrades it.")
    draft = dict(incident)
    draft["priority_score"] = score
    draft["priority_band"] = priority_band
    draft["priority_reasons"] = reasons
    sitrep = render_sitrep(draft, logistics, team, shelter)
    return {
        "agent": "triage",
        "mode": mode,
        "model": settings.model_main,
        "priority_score": score,
        "priority_band": priority_band,
        "priority_capped": capped,
        "priority_reasons": reasons,
        "logistics": logistics,
        "suggested_team": team,
        "standby_team": standby,
        "shelter": shelter,
        "sitrep_markdown": sitrep,
        "summary_line": (
            f"Priority {score} {priority_band}. "
            + (f"Suggest {team['name']}, ETA {team['eta_min']} min." if team else "No team seeded.")
        ),
    }
