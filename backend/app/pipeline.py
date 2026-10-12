"""One-report orchestration. Order matches the ADK SequentialAgent."""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from app.agents.dedup import run_dedup, token_embedding
from app.agents.intake import run_intake
from app.agents.live import apply_review, maybe_review
from app.agents.triage import run_triage
from app.agents.verification import run_verification
from app.bmkg import area_for, bind_snapshot, earthquake_snapshot
from app.config import Settings
from app.geo import haversine_m
from app.media import MediaStore, read_exif
from app.notify import Notifier
from app.store import MemoryStore


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _public(incident: dict[str, Any]) -> dict[str, Any]:
    data = dict(incident)
    data.pop("embedding", None)
    data.pop("embed_text", None)
    return data


class Pipeline:
    def __init__(self, settings: Settings, store: MemoryStore, media: MediaStore, notifier: Notifier) -> None:
        self.settings = settings
        self.store = store
        self.media = media
        self.notifier = notifier
        self.scenarios = self._discover_scenarios()
        default_id = self._default_scenario_id()
        self.scenario_id = default_id
        self.scenario = self._activate(default_id)

    def _discover_scenarios(self) -> dict[str, dict[str, Any]]:
        import json

        folder = self.settings.scenario_path.parent
        found: dict[str, dict[str, Any]] = {}
        paths = {self.settings.scenario_path.resolve()}
        if folder.is_dir():
            paths.update(p.resolve() for p in folder.glob("*.json"))
        for path in sorted(paths, key=lambda p: p.name):
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            if not isinstance(data, dict) or not data.get("reports"):
                continue
            sid = str(data.get("id") or path.stem)
            data = dict(data)
            data["_path"] = str(path)
            found[sid] = data
        if not found:
            raise FileNotFoundError(f"No scenario JSON found next to {self.settings.scenario_path}")
        return found

    def _default_scenario_id(self) -> str:
        import json

        try:
            data = json.loads(self.settings.scenario_path.read_text(encoding="utf-8"))
            sid = str(data.get("id") or self.settings.scenario_path.stem)
            if sid in self.scenarios:
                return sid
        except (OSError, json.JSONDecodeError, KeyError):
            pass
        if "dayeuhkolot-flood-2026" in self.scenarios:
            return "dayeuhkolot-flood-2026"
        return next(iter(self.scenarios))

    def list_scenarios(self) -> list[dict[str, Any]]:
        items = []
        for sid, data in self.scenarios.items():
            items.append(
                {
                    "id": sid,
                    "title": data.get("title") or sid,
                    "summary": data.get("summary") or "",
                    "hazard": data.get("hazard") or "",
                    "reports": len(data.get("reports") or []),
                    "active": sid == self.scenario_id,
                }
            )
        items.sort(key=lambda item: (0 if "flood" in item["id"] else 1, item["title"]))
        return items

    def _activate(self, scenario_id: str) -> dict[str, Any]:
        if scenario_id not in self.scenarios:
            raise KeyError(scenario_id)
        data = self.scenarios[scenario_id]
        bind_snapshot(data.get("bmkg") or {})
        self.store.resources = data.get("resources") or {"teams": [], "shelters": []}
        self.scenario_id = scenario_id
        self.scenario = data
        return data

    def set_scenario(self, scenario_id: str) -> dict[str, Any]:
        data = self._activate(scenario_id)
        self.reset()
        return data

    def seed_presence(self) -> None:
        for item in self.scenario.get("presence") or []:
            self.store.set_presence(item)

    def reset(self) -> None:
        self.store.reset_operational()
        self.seed_presence()

    def ingest(self, raw: dict[str, Any], force_mode: str | None = None) -> dict[str, Any]:
        prepared = self._prepare(raw)
        mode = force_mode or self.settings.mode
        intake = run_intake(prepared, self.settings, mode="mock" if mode == "mock" else "live")
        area = area_for(intake["place_key"])
        quake = earthquake_snapshot()
        with self.store.lock():
            nearby = self._nearby_count(prepared, intake)
            verification = run_verification(
                prepared, intake, area, quake, nearby, self.settings, mode=intake["mode"]
            )
        review = {"mode": "mock"}
        if mode == "live":
            review = asyncio.run(maybe_review(self.settings, prepared, intake, verification))
            apply_review(intake, verification, review)
            mode_label = review.get("mode") or "live_fallback"
            intake["mode"] = mode_label
            verification["mode"] = mode_label
        with self.store.lock():
            return self._commit(prepared, intake, verification, review.get("mode") or mode)

    def _prepare(self, raw: dict[str, Any]) -> dict[str, Any]:
        report = dict(raw)
        report["id"] = str(report.get("id") or f"rpt-{uuid4().hex[:8]}")
        report["channel"] = report.get("channel") or "app"
        report["reporter_id"] = str(report.get("reporter_id") or "anonymous")
        report["text"] = report.get("text") or ""
        report["lat"] = float(report["lat"])
        report["lng"] = float(report["lng"])
        report["created_at"] = report.get("created_at") or _now()
        if report.get("photo_base64"):
            name = self.media.save_base64(report["id"], "photo", report.pop("photo_base64"))
            report["photo_file"] = name
            path = self.media.resolve(name, self.settings.media_dir)
            if path and not report.get("exif"):
                report["exif"] = read_exif(path.read_bytes())
        if report.get("audio_base64"):
            report["audio_file"] = self.media.save_base64(report["id"], "audio", report.pop("audio_base64"))
        report.pop("photo_base64", None)
        report.pop("audio_base64", None)
        return report

    def _nearby_count(self, report: dict[str, Any], intake: dict[str, Any]) -> int:
        count = 0
        for other in self.store.reports.values():
            if other["id"] == report["id"]:
                continue
            other_hazard = (other.get("intake") or {}).get("hazard_type")
            if other_hazard != intake.get("hazard_type"):
                continue
            dist = haversine_m(report["lat"], report["lng"], float(other["lat"]), float(other["lng"]))
            if dist <= self.settings.nearby_radius_m:
                count += 1
        return count

    def _commit(
        self,
        report: dict[str, Any],
        intake: dict[str, Any],
        verification: dict[str, Any],
        mode: str,
    ) -> dict[str, Any]:
        if report["id"] in self.store.reports:
            existing = self.store.reports[report["id"]]
            incident = self.store.incidents.get(existing.get("incident_id") or "")
            return {"report": existing, "incident": _public(incident) if incident else None, "duplicate": True}

        decision = run_dedup(report, intake, verification, list(self.store.incidents.values()), self.settings, mode=mode)
        decision_public = {k: v for k, v in decision.items() if k != "embedding"}
        now = _now()
        created = False
        if decision["action"] == "merge" and decision["incident_id"] in self.store.incidents:
            incident = self.store.incidents[decision["incident_id"]]
        else:
            created = True
            incident = {
                "id": f"inc-{uuid4().hex[:8]}",
                "hazard_type": intake["hazard_type"],
                "cluster_key": intake["place_key"],
                "place_label": intake["place_label"],
                "title": f"{intake['hazard_type'].replace('_', ' ').title()} — {intake['place_label'].split(',')[0]}",
                "lat": report["lat"],
                "lng": report["lng"],
                "report_ids": [],
                "channels": [],
                "reporter_ids": [],
                "people_affected": 0,
                "trapped": 0,
                "vulnerable": [],
                "needs": [],
                "severity": 1,
                "status": "open",
                "decision": None,
                "updates_since_decision": 0,
                "operator_notified": False,
                "created_at": now,
                "embed_text": "",
            }
        incident["report_ids"] = list(dict.fromkeys([*incident["report_ids"], report["id"]]))
        incident["channels"] = list(dict.fromkeys([*incident.get("channels", []), report["channel"]]))
        incident["reporter_ids"] = list(dict.fromkeys([*incident.get("reporter_ids", []), report["reporter_id"]]))
        incident["people_affected"] = max(int(incident.get("people_affected") or 0), int(intake["people_affected"]))
        incident["trapped"] = max(int(incident.get("trapped") or 0), int(intake["trapped"]))
        incident["vulnerable"] = list(dict.fromkeys([*incident.get("vulnerable", []), *intake["vulnerable"]]))
        incident["needs"] = list(dict.fromkeys([*incident.get("needs", []), *intake["needs"]]))
        incident["severity"] = max(int(incident.get("severity") or 1), int(intake["severity"]))
        members = [self.store.reports[rid] for rid in incident["report_ids"] if rid in self.store.reports]
        # Include the report we are about to save so the average uses it.
        creds = [int((m.get("verification") or {}).get("credibility") or 0) for m in members]
        creds.append(int(verification["credibility"]))
        incident["credibility"] = int(round(sum(creds) / len(creds)))
        incident["credibility_reasons"] = list(verification["reasons"])
        if len(incident["report_ids"]) > 1:
            incident["credibility_reasons"] = [
                *incident["credibility_reasons"],
                f"Merged {len(incident['report_ids'])} reports from {', '.join(incident['channels'])}.",
            ]
        lats = [float(m["lat"]) for m in members] + [float(report["lat"])]
        lngs = [float(m["lng"]) for m in members] + [float(report["lng"])]
        incident["lat"] = sum(lats) / len(lats)
        incident["lng"] = sum(lngs) / len(lngs)
        incident["embed_text"] = (incident.get("embed_text") or "") + "\n" + (intake.get("transcript") or "")
        incident["embedding"] = decision.get("embedding") or token_embedding(incident["embed_text"])
        incident["summary"] = self._summary(incident, intake)
        incident["updated_at"] = now
        if incident.get("decision"):
            incident["updates_since_decision"] = int(incident.get("updates_since_decision") or 0) + (0 if created else 1)
        triage = run_triage(incident, self.store.resources, self.settings, mode=mode if mode != "live" else verification["mode"])
        for key in (
            "priority_score",
            "priority_band",
            "priority_reasons",
            "logistics",
            "suggested_team",
            "standby_team",
            "shelter",
            "sitrep_markdown",
        ):
            incident[key] = triage[key]
        incident["agent_trace"] = [
            {"agent": "intake", "mode": intake["mode"], "model": intake["model"], "summary": intake["summary"]},
            {
                "agent": "verification",
                "mode": verification["mode"],
                "model": verification["model"],
                "summary": f"Credibility {verification['credibility']}/100 ({verification['band']}).",
            },
            {"agent": "dedup", "mode": decision["mode"], "model": decision["model"], "summary": decision["reason"]},
            {"agent": "triage", "mode": triage["mode"], "model": triage["model"], "summary": triage["summary_line"]},
        ]
        report["status"] = "triaged"
        report["incident_id"] = incident["id"]
        report["language"] = intake["language"]
        report["transcript"] = intake["transcript"]
        report["translation_en"] = intake["translation_en"]
        report["photo_url"] = f"/media/{report['photo_file']}" if report.get("photo_file") else None
        report["audio_url"] = f"/media/{report['audio_file']}" if report.get("audio_file") else None
        report["intake"] = intake
        report["verification"] = verification
        report["dedup"] = decision_public
        self.store.upsert_report(report)
        self.store.upsert_incident(incident)
        if created and incident["priority_band"] in {"critical", "high"} and not incident["operator_notified"]:
            self.notifier.push(
                {
                    "id": f"ntf-{uuid4().hex[:8]}",
                    "type": "operator_ticket",
                    "title": f"New {incident['priority_band']} ticket",
                    "body": f"{incident['title']} · priority {incident['priority_score']}. No citizen alert has been sent.",
                    "incident_id": incident["id"],
                    "reporter_id": None,
                    "topic": "tipo-operators",
                    "created_at": now,
                }
            )
            incident["operator_notified"] = True
            self.store.upsert_incident(incident)
        return {"report": report, "incident": _public(incident), "duplicate": False}

    def _summary(self, incident: dict[str, Any], intake: dict[str, Any]) -> str:
        people = int(incident.get("people_affected") or 0)
        people_bit = f"about {people} people" if people else "no confirmed headcount"
        vuln = incident.get("vulnerable") or []
        vuln_bit = f", including {', '.join(vuln)}" if vuln else ""
        return (
            f"{str(incident['hazard_type']).title()} around {incident['place_label']}: {people_bit}{vuln_bit}. "
            f"{len(incident['report_ids'])} report(s) merged from {', '.join(incident['channels'])}. "
            f"Latest reading: {intake['summary']}"
        )

    def decide(self, incident_id: str, body: dict[str, Any]) -> dict[str, Any]:
        with self.store.lock():
            incident = self.store.incidents.get(incident_id)
            if not incident:
                raise KeyError(incident_id)
            action = body.get("action")
            if action not in {"approve", "reject", "edit"}:
                raise ValueError("action must be approve, reject, or edit")
            if body.get("priority_band"):
                incident["priority_band"] = body["priority_band"]
            if body.get("people_affected") is not None:
                incident["people_affected"] = int(body["people_affected"])
            if body.get("needs") is not None:
                incident["needs"] = list(body["needs"])
            if body.get("team_id"):
                teams = self.store.resources.get("teams") or []
                match = next((t for t in teams if t["id"] == body["team_id"]), None)
                if match:
                    current = incident.get("suggested_team") or {}
                    incident["suggested_team"] = {**current, **match, "eta_min": current.get("eta_min", 15)}
            note = (body.get("note") or "").strip()
            operator = body.get("operator_name") or "Posko operator"
            now = _now()
            if action == "edit":
                incident["status"] = incident.get("status") or "open"
            elif action == "reject":
                incident["status"] = "rejected"
            else:
                incident["status"] = "approved"
            send_alert = bool(body.get("send_alert")) and action == "approve"
            incident["decision"] = {
                "action": action,
                "operator_name": operator,
                "note": note,
                "alert_sent": send_alert,
                "decided_at": now,
            }
            incident["updates_since_decision"] = 0
            incident["updated_at"] = now
            triage = run_triage(incident, self.store.resources, self.settings, mode=self.settings.mode)
            incident["logistics"] = triage["logistics"]
            incident["sitrep_markdown"] = triage["sitrep_markdown"]
            if not body.get("priority_band"):
                incident["priority_score"] = triage["priority_score"]
                incident["priority_band"] = triage["priority_band"]
                incident["priority_reasons"] = triage["priority_reasons"]
            for rid in incident["report_ids"]:
                report = self.store.reports.get(rid)
                if not report:
                    continue
                report["status"] = "rejected" if action == "reject" else "approved" if action == "approve" else report["status"]
                self.store.upsert_report(report)
            self.store.upsert_incident(incident)
            self._fanout(incident, action, send_alert, operator, note)
            return _public(incident)

    def _fanout(self, incident: dict[str, Any], action: str, send_alert: bool, operator: str, note: str) -> None:
        if action == "edit":
            return
        now = _now()
        team = (incident.get("suggested_team") or {}).get("name")
        for reporter_id in incident.get("reporter_ids") or []:
            if action == "approve":
                body = (
                    f"Your report was verified by {operator}. "
                    + (f"Assigned team: {team}. " if team else "")
                    + "This update was approved by a person at the posko. "
                    + (note or "Follow instructions from the posko.")
                )
                title = "Report verified"
            else:
                body = (
                    f"{operator} reviewed your report and did not corroborate it. "
                    "No public alert was sent. If you are in danger, call 112. "
                    + (note or "")
                ).strip()
                title = "Report reviewed"
            self.notifier.push(
                {
                    "id": f"ntf-{uuid4().hex[:8]}",
                    "type": "reporter_status",
                    "title": title,
                    "body": body,
                    "incident_id": incident["id"],
                    "reporter_id": reporter_id,
                    "created_at": now,
                }
            )
        if not send_alert:
            return
        recipients = self._nearby_recipients(incident)
        for reporter_id in recipients:
            self.notifier.push(
                {
                    "id": f"ntf-{uuid4().hex[:8]}",
                    "type": "nearby_alert",
                    "title": f"{str(incident['hazard_type']).title()} near {incident['place_label'].split(',')[0]}",
                    "body": (
                        f"A posko operator confirmed a {incident['hazard_type']} near {incident['place_label']}. "
                        "Avoid low ground and follow posko instructions. "
                        "This alert was sent by a human, not by the model."
                    ),
                    "incident_id": incident["id"],
                    "reporter_id": reporter_id,
                    "created_at": now,
                }
            )

    def _nearby_recipients(self, incident: dict[str, Any]) -> list[str]:
        originators = set(incident.get("reporter_ids") or [])
        found: list[str] = []
        points = list(self.store.presence.values())
        for report in self.store.reports.values():
            points.append({"reporter_id": report["reporter_id"], "lat": report["lat"], "lng": report["lng"]})
        seen = set()
        for point in points:
            rid = point.get("reporter_id")
            if not rid or rid in originators or rid in seen:
                continue
            dist = haversine_m(float(incident["lat"]), float(incident["lng"]), float(point["lat"]), float(point["lng"]))
            if dist <= self.settings.nearby_radius_m:
                seen.add(rid)
                found.append(rid)
        return found
