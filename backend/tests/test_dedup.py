from app.agents.dedup import cosine, run_dedup, token_embedding
from app.config import load_settings

SETTINGS = load_settings()


def _report(lat=-6.976, lng=107.626):
    return {"lat": lat, "lng": lng}


def _incident(cred=86, hazard="flood", key="dayeuhkolot"):
    return {
        "id": "inc-real",
        "title": "Flood — Dayeuhkolot",
        "hazard_type": hazard,
        "cluster_key": key,
        "credibility": cred,
        "lat": -6.975,
        "lng": 107.625,
        "status": "open",
        "embed_text": "banjir dayeuhkolot rw 04 air dada lansia perahu",
    }


def test_same_place_merges():
    intake = {"hazard_type": "flood", "place_key": "dayeuhkolot", "transcript": "banjir dayeuhkolot rw 04 butuh perahu"}
    verification = {"credibility": 84}
    decision = run_dedup(_report(), intake, verification, [_incident()], SETTINGS)
    assert decision["action"] == "merge"
    assert decision["incident_id"] == "inc-real"


def test_low_credibility_does_not_join_a_confirmed_incident():
    intake = {"hazard_type": "flood", "place_key": "dayeuhkolot", "transcript": "banjir dahsyat dayeuhkolot air setinggi rumah"}
    verification = {"credibility": 12}
    decision = run_dedup(_report(), intake, verification, [_incident()], SETTINGS)
    assert decision["action"] == "new"
    assert "40" in decision["reason"] or "credibility" in decision["reason"].lower()


def test_different_hazard_stays_separate():
    intake = {"hazard_type": "landslide", "place_key": "cangkuang", "transcript": "longsor kecil cangkuang"}
    verification = {"credibility": 80}
    decision = run_dedup(_report(lat=-6.99, lng=107.612), intake, verification, [_incident()], SETTINGS)
    assert decision["action"] == "new"


def test_token_embedding_is_deterministic():
    text = "perahu lansia dayeuhkolot"
    assert cosine(token_embedding(text), token_embedding(text)) > 0.99
