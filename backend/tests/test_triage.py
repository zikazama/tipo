from app.agents.triage import priority_score, run_triage
from app.config import load_settings

SETTINGS = load_settings()
RESOURCES = {
    "teams": [
        {"id": "boat-dk-1", "name": "Rubber boat 1", "kind": "boat", "posko": "Posko Dayeuhkolot", "lat": -6.9712, "lng": 107.6180, "crew": 4},
        {"id": "boat-dk-2", "name": "Rubber boat 2", "kind": "boat", "posko": "Posko Dayeuhkolot", "lat": -6.9715, "lng": 107.6186, "crew": 4},
    ],
    "shelters": [
        {"id": "sdn-dk", "name": "SDN Dayeuhkolot 1", "lat": -6.9718, "lng": 107.6188, "capacity": 200, "occupied": 40},
    ],
}


def test_critical_flood_suggests_two_boats_and_a_draft_sitrep():
    incident = {
        "id": "inc-dk",
        "hazard_type": "flood",
        "place_label": "Dayeuhkolot, Kabupaten Bandung, West Java",
        "lat": -6.9755,
        "lng": 107.625,
        "people_affected": 160,
        "trapped": 8,
        "vulnerable": ["elderly", "infants"],
        "needs": ["boat", "evacuation", "water"],
        "severity": 5,
        "credibility": 86,
        "channels": ["app", "voice"],
        "report_ids": ["rpt-01", "rpt-03"],
        "status": "open",
        "summary": "Flood around Dayeuhkolot.",
        "updated_at": "2026-10-10T09:40:00+00:00",
    }
    result = run_triage(incident, RESOURCES, SETTINGS)
    assert result["priority_band"] == "critical"
    assert result["priority_score"] >= 80
    assert result["logistics"]["water_liters_per_day"] == 480
    assert result["logistics"]["ready_meals"] == 320
    assert result["logistics"]["boats"] == 2
    assert result["suggested_team"]["id"] == "boat-dk-1"
    assert result["standby_team"]["id"] == "boat-dk-2"
    assert result["suggested_team"]["eta_min"] <= 20
    assert "BNPB-style" in result["sitrep_markdown"]
    assert "Dayeuhkolot" in result["sitrep_markdown"]
    assert "human operator" in result["sitrep_markdown"].lower()
    assert "alert was sent" not in result["sitrep_markdown"].lower()


def test_low_credibility_is_capped():
    score, capped = priority_score(5, 0, [], 12, [], 0)
    assert capped
    assert score < 40
