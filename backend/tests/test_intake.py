from app.agents.intake import run_intake
from app.config import load_settings

SETTINGS = load_settings()


def test_sundanese_voice_extracts_flood_and_elderly():
    result = run_intake(
        {
            "text": "Punten, cai di Dayeuhkolot RW 04 geus naek nepi ka dada. Aya kolot nu kejebak di lantai dua, teu tiasa turun. Butuh perahu.",
            "audio_file": "voice_su_elderly.wav",
            "lat": -6.97,
            "lng": 107.62,
        },
        SETTINGS,
    )
    assert result["language"] == "su"
    assert result["hazard_type"] == "flood"
    assert result["place_key"] == "dayeuhkolot"
    assert "elderly" in result["vulnerable"]
    assert "boat" in result["needs"]
    assert result["severity"] == 5
    assert result["transcribe_model"] == SETTINGS.model_transcribe
    assert result["model"] == "gemini-3.8-flash"


def test_javanese_voice_extracts_medicine_need():
    result = run_intake(
        {
            "text": "Ngapunten, banyu ing Baleendah Andir wis nganti dengkul. Ana wong tuwa sing lara, butuh obat.",
            "lat": -7.0,
            "lng": 107.63,
        },
        SETTINGS,
    )
    assert result["language"] == "jv"
    assert result["hazard_type"] == "flood"
    assert result["place_key"] == "baleendah"
    assert "elderly" in result["vulnerable"]
    assert "medicine" in result["needs"]
    assert result["severity"] == 3


def test_household_and_people_counts():
    result = run_intake(
        {
            "text": "Banjir di Jalan Dayeuhkolot, sekitar 40 rumah tangga terendam, kira-kira 160 jiwa.",
            "lat": -6.97,
            "lng": 107.62,
        },
        SETTINGS,
    )
    assert result["people_affected"] == 160


def test_negated_trapped_does_not_raise_severity():
    result = run_intake(
        {
            "text": "Air mulai masuk ke rumah di Bojongsoang, sekitar 45 jiwa terdampak. Belum ada yang terjebak.",
            "lat": -7.0,
            "lng": 107.65,
        },
        SETTINGS,
    )
    assert result["trapped"] == 0
    assert "evacuation" not in result["needs"]
    assert result["severity"] == 3
    assert result["people_affected"] == 45


def test_hazard_hint_fills_in_only_when_text_is_silent():
    silent = run_intake({"text": "Tolong, jalan depan rumah tertutup.", "hazard_hint": "landslide", "lat": -7.0, "lng": 107.6}, SETTINGS)
    assert silent["hazard_type"] == "landslide"
    spoken = run_intake({"text": "Banjir di Dayeuhkolot.", "hazard_hint": "fire", "lat": -6.97, "lng": 107.62}, SETTINGS)
    assert spoken["hazard_type"] == "flood"
    unknown = run_intake({"text": "Tolong.", "hazard_hint": "meteor", "lat": -6.97, "lng": 107.62}, SETTINGS)
    assert unknown["hazard_type"] == "other"
