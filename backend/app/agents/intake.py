"""Intake agent: multimodal report -> structured hazard facts."""

from __future__ import annotations

from typing import Any

from app.config import Settings
from app.lexicon import (
    detect_hazard,
    detect_language,
    detect_needs,
    detect_vulnerable,
    extract_counts,
    place_key,
    severity_hint,
)

# The citizen's hazard chip only fills in when the words alone do not name a hazard.
HAZARD_HINTS = {"flood", "landslide", "earthquake", "fire"}
LANG_NAME = {"id": "Indonesian", "su": "Sundanese", "jv": "Javanese", "en": "English"}
PLACE_LABEL = {
    "dayeuhkolot": "Dayeuhkolot, Kabupaten Bandung, West Java",
    "baleendah": "Baleendah, Kabupaten Bandung, West Java",
    "bojongsoang": "Bojongsoang, Kabupaten Bandung, West Java",
    "cangkuang": "Cangkuang Wetan, Kabupaten Bandung, West Java",
    "unknown": "Unconfirmed location",
}


def run_intake(report: dict[str, Any], settings: Settings, mode: str = "mock") -> dict[str, Any]:
    utterance = (report.get("transcript") or report.get("text") or "").strip()
    language = report.get("language") or detect_language(utterance)
    hazard = detect_hazard(utterance)
    hint = (report.get("hazard_hint") or "").strip().lower()
    if hazard == "other" and hint in HAZARD_HINTS:
        hazard = hint
    counts = extract_counts(utterance)
    vulnerable = detect_vulnerable(utterance)
    needs = detect_needs(utterance)
    key = report.get("place_key") or place_key(utterance, report.get("place_name") or "")
    severity = int(report["severity"]) if report.get("severity") else severity_hint(utterance)
    translation = (report.get("translation_en") or "").strip()
    if not translation:
        if language in {"id", "en"}:
            translation = utterance
        else:
            translation = (
                f"{LANG_NAME.get(language, language)} report. "
                "Mock mode keeps the transcript and extracts structured fields from regional keywords. "
                "Live mode translates with the intake model."
            )
    summary_bits = [f"{hazard.replace('_', ' ').title()} report in {PLACE_LABEL.get(key, key)}."]
    if counts["people_affected"]:
        summary_bits.append(f"About {counts['people_affected']} people mentioned.")
    if counts["trapped"]:
        summary_bits.append(f"{counts['trapped']} described as trapped.")
    if vulnerable:
        summary_bits.append("Vulnerable groups: " + ", ".join(vulnerable) + ".")
    audio = bool(report.get("audio_file") or report.get("audio_base64") or report.get("audio_url"))
    return {
        "agent": "intake",
        "mode": mode,
        "model": settings.model_main,
        "transcribe_model": settings.model_transcribe if audio else None,
        "hazard_type": hazard,
        "language": language,
        "language_name": LANG_NAME.get(language, language),
        "transcript": utterance,
        "translation_en": translation,
        "place_key": key,
        "place_label": report.get("place_name") or PLACE_LABEL.get(key, key),
        "severity": severity,
        "people_affected": counts["people_affected"],
        "trapped": counts["trapped"],
        "vulnerable": vulnerable,
        "needs": needs,
        "summary": " ".join(summary_bits),
        "has_photo": bool(report.get("photo_file") or report.get("photo_base64") or report.get("photo_url")),
        "has_audio": audio,
    }
