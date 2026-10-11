"""Report, incident, and notification storage.

Memory is the default so mock mode and tests need no GCP project. Firestore is
used when TIPO_STORE=firestore and a project id is set.
"""

from __future__ import annotations

import threading
from typing import Any

from app.config import Settings


class MemoryStore:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.reports: dict[str, dict[str, Any]] = {}
        self.incidents: dict[str, dict[str, Any]] = {}
        self.notifications: list[dict[str, Any]] = []
        self.presence: dict[str, dict[str, Any]] = {}
        self.resources: dict[str, Any] = {"teams": [], "shelters": []}

    def lock(self) -> threading.Lock:
        return self._lock

    def reset_operational(self) -> None:
        with self._lock:
            self.reports.clear()
            self.incidents.clear()
            self.notifications.clear()

    def upsert_report(self, report: dict[str, Any]) -> None:
        self.reports[report["id"]] = report

    def upsert_incident(self, incident: dict[str, Any]) -> None:
        self.incidents[incident["id"]] = incident

    def add_notification(self, item: dict[str, Any]) -> None:
        self.notifications.append(item)

    def set_presence(self, item: dict[str, Any]) -> None:
        with self._lock:
            self.presence[item["reporter_id"]] = item

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            return {
                "reports": list(self.reports.values()),
                "incidents": list(self.incidents.values()),
                "notifications": list(self.notifications),
                "presence": list(self.presence.values()),
                "resources": self.resources,
            }


class FirestoreStore(MemoryStore):
    """Write-through cache. Reads served from memory after each write, and hydrated on startup."""

    def __init__(self, project: str) -> None:
        super().__init__()
        from google.cloud import firestore

        self._db = firestore.Client(project=project)
        self._hydrate()

    def _hydrate(self) -> None:
        for doc in self._db.collection("reports").stream():
            self.reports[doc.id] = doc.to_dict()
        for doc in self._db.collection("incidents").stream():
            self.incidents[doc.id] = doc.to_dict()
        for doc in self._db.collection("notifications").stream():
            self.notifications.append(doc.to_dict())

    def upsert_report(self, report: dict[str, Any]) -> None:
        super().upsert_report(report)
        self._db.collection("reports").document(report["id"]).set(report)

    def upsert_incident(self, incident: dict[str, Any]) -> None:
        super().upsert_incident(incident)
        self._db.collection("incidents").document(incident["id"]).set(incident)

    def add_notification(self, item: dict[str, Any]) -> None:
        super().add_notification(item)
        self._db.collection("notifications").document(item["id"]).set(item)

    def reset_operational(self) -> None:
        super().reset_operational()
        for name in ("reports", "incidents", "notifications"):
            for doc in self._db.collection(name).stream():
                doc.reference.delete()


def build_store(settings: Settings) -> MemoryStore:
    if settings.use_firestore:
        try:
            return FirestoreStore(settings.firestore_project)
        except Exception:
            # Missing credentials should not take down the mock demo.
            return MemoryStore()
    return MemoryStore()
