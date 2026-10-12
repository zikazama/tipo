"""Verification agent: explainable credibility using EXIF, vision cues, and BMKG."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from app.config import Settings
from app.geo import clamp, haversine_m


def _parse_time(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def run_verification(
    report: dict[str, Any],
    intake: dict[str, Any],
    bmkg_area: dict[str, Any],
    earthquake: dict[str, Any],
    nearby_same_hazard: int,
    settings: Settings,
    now: datetime | None = None,
    mode: str = "mock",
) -> dict[str, Any]:
    now = now or datetime.now(timezone.utc)
    score = 64.0
    reasons: list[str] = []
    exif = report.get("exif") or {}
    taken = _parse_time(exif.get("taken_at") if isinstance(exif, dict) else None)
    if not exif or not taken:
        reasons.append("No EXIF timestamp on the photo. Treated as neutral, not as evidence of a fake.")
    else:
        age_days = (now - taken).total_seconds() / 86400
        if age_days > 14:
            score -= 32
            reasons.append(
                f"EXIF timestamp is {taken.date().isoformat()} ({int(age_days)} days before this report). "
                "Old-photo cue. This is a signal, not a verdict."
            )
        else:
            score += 4
            reasons.append(f"EXIF timestamp {taken.isoformat()} is close to the report time.")
        if exif.get("lat") is not None and exif.get("lng") is not None:
            gap = haversine_m(float(report["lat"]), float(report["lng"]), float(exif["lat"]), float(exif["lng"]))
            if gap > 25_000:
                score -= 20
                reasons.append(
                    f"EXIF GPS is {gap / 1000:.0f} km from the pin the sender dropped. "
                    "The picture may not have been taken at the claimed place."
                )
            elif gap > 2_000:
                score -= 6
                reasons.append(f"EXIF GPS is {gap / 1000:.1f} km from the dropped pin.")
            else:
                reasons.append("EXIF GPS agrees with the dropped pin.")

    cues = [c for c in (report.get("image_cues") or []) if c]
    strong = 0
    for cue in cues:
        low = cue.lower()
        if any(w in low for w in ("watermark", "screenshot", "coastal", "beach", "2023", "2024", "repost", "old")):
            strong += 1
            score -= 8
            reasons.append(f"Visual cue: {cue}.")
    if strong > 2:
        score += (strong - 2) * 8  # cap the cue penalty at two steps

    hazard = intake.get("hazard_type")
    rain = float(bmkg_area.get("tp_mm") or 0)
    desc = bmkg_area.get("weather_desc_en") or "unknown"
    adm4 = bmkg_area.get("adm4") or "n/a"
    name = bmkg_area.get("name") or intake.get("place_label")
    source = bmkg_area.get("source") or "scenario_snapshot"
    if hazard in {"flood", "landslide"}:
        if rain >= 20:
            score += 16
            reasons.append(
                f"BMKG {source.replace('_', ' ')} for {name} (adm4 {adm4}): {desc}, {rain:.0f} mm. "
                "Weather is consistent with this hazard."
            )
        elif rain < 5:
            score -= 10
            reasons.append(
                f"BMKG data for {name} (adm4 {adm4}) shows {desc}, {rain:.0f} mm. Weak environmental support."
            )
        else:
            reasons.append(f"BMKG data for {name}: {desc}, {rain:.0f} mm. Partial support.")
    elif hazard == "fire":
        fire_risk = str(bmkg_area.get("fire_risk") or "").lower()
        dry = rain < 5 or any(w in desc.lower() for w in ("haze", "hot", "dry", "clear", "sunny"))
        if dry or fire_risk in {"high", "elevated", "severe"}:
            score += 14
            risk_bit = f", fire risk {fire_risk}" if fire_risk else ""
            reasons.append(
                f"BMKG {source.replace('_', ' ')} for {name} (adm4 {adm4}): {desc}, {rain:.0f} mm{risk_bit}. "
                "Dry or hazy conditions are consistent with karhutla spread. "
                "This is weather context, not a live hotspot feed."
            )
        elif rain >= 20:
            score -= 8
            reasons.append(
                f"BMKG data for {name} (adm4 {adm4}) shows {desc}, {rain:.0f} mm. "
                "Wet conditions give weak support for an active land fire."
            )
        else:
            reasons.append(f"BMKG data for {name}: {desc}, {rain:.0f} mm. Partial support for a fire claim.")
    elif hazard == "earthquake":
        place = earthquake.get("place") or "unknown"
        mag = earthquake.get("magnitude")
        coords = earthquake.get("coordinates") or [0, 0]
        gap_km = haversine_m(float(report["lat"]), float(report["lng"]), float(coords[0]), float(coords[1])) / 1000
        if gap_km > 150 or (mag is not None and float(mag) < 4.5):
            score -= 28
            reasons.append(
                f"Latest BMKG autogempa is M{mag} — {place} ({earthquake.get('time_wib', 'time unknown')}), "
                f"about {gap_km:.0f} km from this pin. No local quake supports the claim."
            )
        else:
            score += 18
            reasons.append(f"BMKG lists a recent quake that fits this report: M{mag}, {place}.")

    if nearby_same_hazard >= 1:
        bonus = min(12, 4 * nearby_same_hazard)
        score += bonus
        reasons.append(
            f"{nearby_same_hazard} other report(s) of the same hazard are already open within "
            f"{int(settings.nearby_radius_m)} m."
        )
    elif score < 50:
        reasons.append("No nearby report corroborates this claim yet.")

    credibility = int(round(clamp(score, 8, 96)))
    band = "high" if credibility >= 70 else "mixed" if credibility >= 40 else "low"
    return {
        "agent": "verification",
        "mode": mode,
        "model": settings.model_main,
        "credibility": credibility,
        "band": band,
        "reasons": reasons,
        "bmkg": {
            "adm4": adm4,
            "weather_desc_en": desc,
            "tp_mm": rain,
            "source": source,
            "earthquake": earthquake,
        },
    }
