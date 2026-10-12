"""Replay a seeded scenario over about 60–90 seconds."""

from __future__ import annotations

import asyncio
from typing import Any

from app.config import Settings
from app.pipeline import Pipeline


class ReplayEngine:
    def __init__(self, settings: Settings, pipeline: Pipeline) -> None:
        self.settings = settings
        self.pipeline = pipeline
        self.running = False
        self.ingested = 0
        self.total = 0
        self.error: str | None = None
        self._task: asyncio.Task | None = None

    def status(self) -> dict[str, Any]:
        scenario = self.pipeline.scenario
        return {
            "running": self.running,
            "ingested": self.ingested,
            "total": self.total or len(scenario.get("reports") or []),
            "error": self.error,
            "speed": self.settings.replay_speed,
            "scenario_id": self.pipeline.scenario_id,
            "scenario_title": scenario.get("title"),
        }

    def kick(self, scenario_id: str | None = None) -> None:
        if self._task and not self._task.done():
            self._task.cancel()
        self._task = asyncio.create_task(self.run(scenario_id=scenario_id))

    async def run(self, scenario_id: str | None = None) -> dict[str, Any]:
        if scenario_id:
            self.pipeline.set_scenario(scenario_id)
        reports = list(self.pipeline.scenario.get("reports") or [])
        self.pipeline.reset()
        self.total = len(reports)
        self.ingested = 0
        self.error = None
        self.running = True
        try:
            for index, raw in enumerate(reports):
                delay = float(raw.get("delay_s") or 0) * self.settings.replay_speed
                if delay > 0:
                    await asyncio.sleep(delay)
                # Replay is deterministic even if the server default is live.
                self.pipeline.ingest(raw, force_mode="mock")
                self.ingested = index + 1
        except asyncio.CancelledError:
            self.error = "cancelled"
            raise
        except Exception as exc:
            self.error = str(exc)
        finally:
            self.running = False
        return self.status()
