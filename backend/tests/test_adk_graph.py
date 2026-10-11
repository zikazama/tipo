from app.agents.adk_pipeline import build_pipeline
from app.bmkg import bmkg_forecast
from app.config import Settings
from app.main import create_app


def test_sequential_agent_uses_configured_models(monkeypatch):
    monkeypatch.setenv("TIPO_MODEL_MAIN", "gemini-3.8-flash")
    monkeypatch.setenv("TIPO_MODEL_LITE", "gemini-3.5-flash-lite")
    settings = Settings(
        mode="mock",
        model_main="gemini-3.8-flash",
        model_lite="gemini-3.5-flash-lite",
        model_transcribe="gemini-3.5-transcribe",
        model_embed="gemini-embedding-2-preview",
        replay_speed=0,
        data_dir=Settings.__dataclass_fields__["data_dir"].default if False else __import__("pathlib").Path("/tmp"),
        scenario_path=__import__("pathlib").Path("/tmp"),
        media_dir=__import__("pathlib").Path("/tmp"),
        gcs_bucket="",
        firestore_project="",
        google_cloud_location="asia-southeast2",
        nearby_radius_m=2000,
        port=8765,
    )
    # The line above is awkward if Settings has no defaults. Build explicitly.
    root = build_pipeline(settings)
    names = [agent.name for agent in root.sub_agents]
    assert names == ["intake", "verification", "dedup", "triage"]
    assert root.sub_agents[0].model == "gemini-3.8-flash"
    assert root.sub_agents[1].model == "gemini-3.8-flash"
    assert root.sub_agents[2].model == "gemini-3.5-flash-lite"
    assert root.sub_agents[3].model == "gemini-3.8-flash"
    tool_names = [tool.__name__ for tool in root.sub_agents[1].tools]
    assert "bmkg_forecast" in tool_names
    assert "bmkg_earthquakes" in tool_names
    assert "bmkg_nowcast" in tool_names


def test_bmkg_tool_reads_recorded_dayeuhkolot_code():
    create_app()
    forecast = bmkg_forecast("32.04.12.2002")
    assert forecast["adm4"] == "32.04.12.2002"
    assert forecast["tp_mm"] == 45
    assert "Dayeuhkolot" in forecast["name"]
