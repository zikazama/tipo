"""FCM delivery with a mock inbox fallback.

Citizen-facing alerts are only created after an operator approves them.
The pipeline may create an operator_ticket for a new high or critical incident;
that stays inside the posko and is not a public broadcast.
"""

from __future__ import annotations

from typing import Any

from app.config import Settings
from app.store import MemoryStore


class Notifier:
    def __init__(self, settings: Settings, store: MemoryStore) -> None:
        self.settings = settings
        self.store = store
        self._app = None

    def push(self, item: dict[str, Any]) -> dict[str, Any]:
        delivery = "mock_inbox"
        error = None
        if self.settings.fcm_enabled:
            try:
                self._send_fcm(item)
                delivery = "fcm"
            except Exception as exc:  # pragma: no cover - depends on GCP credentials
                error = str(exc)
        stored = dict(item)
        stored["delivery"] = delivery
        if error:
            stored["fcm_error"] = error
        self.store.add_notification(stored)
        return stored

    def _send_fcm(self, item: dict[str, Any]) -> None:
        import firebase_admin
        from firebase_admin import credentials, messaging

        if self._app is None:
            import os

            path = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON") or os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
            cred = credentials.Certificate(path)
            self._app = firebase_admin.initialize_app(cred)
        token = item.get("fcm_token")
        message = messaging.Message(
            notification=messaging.Notification(title=item["title"], body=item["body"]),
            data={
                "type": item["type"],
                "incident_id": item.get("incident_id") or "",
                "reporter_id": item.get("reporter_id") or "",
            },
            token=token if token else None,
            topic=None if token else item.get("topic") or "tipo-operators",
        )
        messaging.send(message)
