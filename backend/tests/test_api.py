def _incident_with(payload, report_id):
    for incident in payload["incidents"]:
        if report_id in incident["report_ids"]:
            return incident
    raise AssertionError(report_id)


def test_health_is_mock(client):
    body = client.get("/api/health").json()
    assert body["status"] == "ok"
    assert body["mode"] == "mock"
    assert body["models"]["main"] == "gemini-3.8-flash"
    assert body["models"]["lite"] == "gemini-3.5-flash-lite"
    assert body["models"]["transcribe"] == "gemini-3.5-transcribe"
    assert body["models"]["embed"] == "gemini-embedding-2-preview"
    assert body["live_credentials"] is False


def test_replay_clusters_hoax_and_holds_alerts(client):
    replayed = client.post("/api/replay?wait=true")
    assert replayed.status_code == 200
    assert replayed.json()["ingested"] == 25
    state = client.get("/api/state").json()
    assert state["replay"]["total"] == 25
    dayeuh = _incident_with(state, "rpt-01")
    assert "rpt-12" in dayeuh["report_ids"]
    assert len(dayeuh["report_ids"]) == 12
    assert "rpt-22" not in dayeuh["report_ids"]
    assert dayeuh["priority_band"] == "critical"
    assert dayeuh["people_affected"] == 160
    assert dayeuh["logistics"]["boats"] == 2
    assert "voice" in dayeuh["channels"] and "petabencana" in dayeuh["channels"]
    hoax = _incident_with(state, "rpt-22")
    assert hoax["id"] != dayeuh["id"]
    assert "rpt-23" in hoax["report_ids"]
    assert hoax["credibility"] < 40
    assert hoax["priority_band"] == "low"
    bale = _incident_with(state, "rpt-14")
    assert bale["priority_band"] == "high"
    assert "rpt-13" in bale["report_ids"]
    bojong = _incident_with(state, "rpt-20")
    assert bojong["priority_band"] == "medium"
    slide = _incident_with(state, "rpt-24")
    assert slide["hazard_type"] == "landslide"
    assert "rpt-25" in slide["report_ids"]
    assert slide["priority_band"] == "low"
    languages = {r["id"]: r["language"] for r in state["reports"]}
    assert languages["rpt-03"] == "su"
    assert languages["rpt-14"] == "jv"
    types = {n["type"] for n in state["notifications"]}
    assert "operator_ticket" in types
    assert "nearby_alert" not in types
    assert "reporter_status" not in types
    span = sum(item["delay_s"] for item in client.app.state.pipeline.scenario["reports"])
    assert 60 <= span <= 90


def test_approve_sends_alerts_and_reject_does_not(client):
    client.post("/api/replay?wait=true")
    state = client.get("/api/state").json()
    dayeuh = _incident_with(state, "rpt-01")
    approved = client.post(
        f"/api/incidents/{dayeuh['id']}/decision",
        json={"action": "approve", "send_alert": True, "operator_name": "Ayu", "note": "Boat team going now."},
    )
    assert approved.status_code == 200
    body = approved.json()
    assert body["status"] == "approved"
    assert body["decision"]["alert_sent"] is True
    notes = client.get("/api/notifications").json()["notifications"]
    nearby = [n for n in notes if n["type"] == "nearby_alert"]
    status = [n for n in notes if n["type"] == "reporter_status" and n["incident_id"] == dayeuh["id"]]
    nearby_ids = {n["reporter_id"] for n in nearby}
    assert {"listener-01", "listener-02", "listener-03"} <= nearby_ids
    assert set(dayeuh["reporter_ids"]).isdisjoint(nearby_ids)
    assert len(status) == len(dayeuh["reporter_ids"])
    assert all("human" in n["body"].lower() or "person" in n["body"].lower() for n in nearby)
    sitrep = client.get(f"/api/incidents/{dayeuh['id']}/sitrep")
    assert sitrep.status_code == 200
    assert "Ayu" in sitrep.text
    assert "nearby alert" in sitrep.text
    hoax = _incident_with(client.get("/api/state").json(), "rpt-22")
    before = len(client.get("/api/notifications").json()["notifications"])
    rejected = client.post(
        f"/api/incidents/{hoax['id']}/decision",
        json={"action": "reject", "send_alert": True, "operator_name": "Ayu"},
    )
    assert rejected.status_code == 200
    assert rejected.json()["decision"]["alert_sent"] is False
    after = client.get("/api/notifications").json()["notifications"]
    new_items = after[before:]
    assert new_items
    assert all(item["type"] == "reporter_status" for item in new_items)


def test_citizen_report_validation_and_edit(client):
    empty = client.post("/api/reports", json={"lat": -6.97, "lng": 107.62, "reporter_id": "judge"})
    assert empty.status_code == 422
    created = client.post(
        "/api/reports",
        json={
            "reporter_id": "judge",
            "channel": "app",
            "text": "Banjir di Dayeuhkolot RW 04, air setinggi dada, 2 lansia terjebak.",
            "lat": -6.976,
            "lng": 107.626,
        },
    )
    assert created.status_code == 200
    incident = created.json()["incident"]
    assert incident["hazard_type"] == "flood"
    edited = client.post(
        f"/api/incidents/{incident['id']}/decision",
        json={"action": "edit", "people_affected": 20, "note": "Operator count"},
    )
    assert edited.status_code == 200
    assert edited.json()["people_affected"] == 20
    assert edited.json()["logistics"]["water_liters_per_day"] == 60
    notes = client.get("/api/notifications?reporter_id=judge").json()["notifications"]
    assert notes == []


def test_live_mode_without_key_falls_back(client, monkeypatch):
    monkeypatch.setenv("TIPO_MODE", "live")
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)
    from app.main import create_app
    from fastapi.testclient import TestClient

    with TestClient(create_app()) as live_client:
        response = live_client.post(
            "/api/reports",
            json={
                "reporter_id": "judge",
                "text": "Banjir di Dayeuhkolot, air setinggi dada.",
                "lat": -6.97,
                "lng": 107.62,
            },
        )
        assert response.status_code == 200
        trace = response.json()["incident"]["agent_trace"]
        assert trace[0]["mode"] == "live_fallback"
        assert response.json()["incident"]["hazard_type"] == "flood"


def test_live_review_overlays_translation(monkeypatch):
    monkeypatch.setenv("TIPO_MODE", "live")
    monkeypatch.setenv("GOOGLE_API_KEY", "test-key")

    async def fake_run(settings, prompt):
        assert "gemini" in settings.model_main or settings.model_main
        return '{"translation_en":"MODEL TRANSLATION","summary":"MODEL SUMMARY","verification_note":"BMKG agrees"}'

    monkeypatch.setattr("app.agents.live.run_adk_text", fake_run)
    from app.main import create_app
    from fastapi.testclient import TestClient

    with TestClient(create_app()) as live_client:
        response = live_client.post(
            "/api/reports",
            json={"reporter_id": "judge", "text": "Banjir di Dayeuhkolot, air setinggi dada.", "lat": -6.97, "lng": 107.62},
        )
        report = response.json()["report"]
        assert report["translation_en"] == "MODEL TRANSLATION"
        assert report["intake"]["mode"] == "live"
        assert any("Gemini review" in reason for reason in report["verification"]["reasons"])
