from datetime import datetime, timezone

from app.agents.verification import run_verification
from app.bmkg import area_for, bind_snapshot, earthquake_snapshot
from app.config import load_settings
from app.main import create_app

SETTINGS = load_settings()
# Bind the recorded snapshot the same way the API does on startup.
create_app()
NOW = datetime(2026, 10, 10, tzinfo=timezone.utc)


def _intake(**overrides):
    data = {
        "hazard_type": "flood",
        "place_key": "dayeuhkolot",
        "place_label": "Dayeuhkolot",
    }
    data.update(overrides)
    return data


def test_old_photo_far_from_pin_scores_low():
    report = {
        "lat": -6.975,
        "lng": 107.626,
        "exif": {"taken_at": "2024-02-11T08:14:00+07:00", "lat": -6.12, "lng": 107.91},
        "image_cues": ["Coastal wave and beach, not a river settlement", "Television watermark: NUSANTARA TV 2024"],
    }
    result = run_verification(
        report,
        _intake(),
        area_for("dayeuhkolot"),
        earthquake_snapshot(),
        nearby_same_hazard=8,
        settings=SETTINGS,
        now=NOW,
    )
    assert result["credibility"] < 40
    assert result["band"] == "low"
    assert any("EXIF timestamp" in reason for reason in result["reasons"])
    assert any("km from the pin" in reason for reason in result["reasons"])
    assert any("BMKG" in reason for reason in result["reasons"])


def test_missing_exif_is_neutral_and_rain_supports_flood():
    report = {"lat": -6.975, "lng": 107.626, "exif": None, "image_cues": []}
    result = run_verification(
        report,
        _intake(),
        area_for("dayeuhkolot"),
        earthquake_snapshot(),
        nearby_same_hazard=0,
        settings=SETTINGS,
        now=NOW,
    )
    assert result["credibility"] >= 70
    assert any("neutral" in reason.lower() for reason in result["reasons"])
    assert any("Heavy rain" in reason or "45" in reason for reason in result["reasons"])


def test_distant_small_quake_does_not_support_a_bandung_claim():
    report = {"lat": -6.975, "lng": 107.626, "exif": None, "image_cues": []}
    result = run_verification(
        report,
        _intake(hazard_type="earthquake"),
        area_for("dayeuhkolot"),
        earthquake_snapshot(),
        nearby_same_hazard=0,
        settings=SETTINGS,
        now=NOW,
    )
    assert result["credibility"] < 50
    assert any("Kendari" in reason for reason in result["reasons"])


def test_snapshot_is_bound_for_known_adm4():
    bind_snapshot(area_for("dayeuhkolot") and __import__("app.bmkg", fromlist=["snapshot"]).snapshot())
    area = area_for("dayeuhkolot")
    assert area["adm4"] == "32.04.12.2002"
    assert area["tp_mm"] == 45
