"""Google ADK graph: Intake -> Verification -> Dedup -> Triage.

The object built here is what live mode executes on Cloud Run. Mock mode does
not call the model; tests assert the graph shape and the model ids from env.
"""

from __future__ import annotations

from google.adk.agents import Agent, SequentialAgent

from app.agents.prompts import DEDUP, INTAKE, PIPELINE, TRIAGE, VERIFICATION
from app.bmkg import bmkg_earthquakes, bmkg_forecast, bmkg_nowcast
from app.config import Settings


def build_pipeline(settings: Settings) -> SequentialAgent:
    intake = Agent(
        name="intake",
        model=settings.model_main,
        description="Extract hazard, place, severity, people, vulnerable groups, and needs from one citizen report.",
        instruction=INTAKE,
        output_key="intake_json",
        disallow_transfer_to_parent=True,
        disallow_transfer_to_peers=True,
    )
    verification = Agent(
        name="verification",
        model=settings.model_main,
        description="Score credibility with EXIF, visual cues, BMKG open data, and nearby reports.",
        instruction=VERIFICATION,
        tools=[bmkg_forecast, bmkg_earthquakes, bmkg_nowcast],
        output_key="verification_json",
        disallow_transfer_to_parent=True,
        disallow_transfer_to_peers=True,
    )
    dedup = Agent(
        name="dedup",
        model=settings.model_lite,
        description="Merge this report into an open incident or open a new one. Never merge a low-credibility claim into a confirmed incident.",
        instruction=DEDUP,
        output_key="dedup_json",
        disallow_transfer_to_parent=True,
        disallow_transfer_to_peers=True,
    )
    triage = Agent(
        name="triage",
        model=settings.model_main,
        description="Priority, logistics, suggested team, and a BNPB-style sitrep draft. Never sends alerts.",
        instruction=TRIAGE,
        output_key="triage_json",
        disallow_transfer_to_parent=True,
        disallow_transfer_to_peers=True,
    )
    return SequentialAgent(
        name="tipo_triage_pipeline",
        description=PIPELINE.strip(),
        sub_agents=[intake, verification, dedup, triage],
    )
