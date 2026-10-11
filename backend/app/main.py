"""TIPO API. Run with uvicorn app.main:app from the backend directory."""

from __future__ import annotations

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import load_settings
from app.media import MediaStore
from app.notify import Notifier
from app.pipeline import Pipeline
from app.replay import ReplayEngine
from app.routes import router
from app.store import build_store


def create_app() -> FastAPI:
    settings = load_settings()
    settings.data_dir.mkdir(parents=True, exist_ok=True)
    store = build_store(settings)
    media = MediaStore(settings)
    notifier = Notifier(settings, store)
    pipeline = Pipeline(settings, store, media, notifier)
    pipeline.seed_presence()
    replay = ReplayEngine(settings, pipeline)
    app = FastAPI(
        title="TIPO",
        summary="TIten POsko — AI disaster triage for posko operators.",
        version="0.1.0",
        description=(
            "Multi-agent triage copilot. Intake, verification, dedup, and triage run on each "
            "citizen report. Public alerts are sent only after a human operator approves them."
        ),
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.state.settings = settings
    app.state.store = store
    app.state.media = media
    app.state.notifier = notifier
    app.state.pipeline = pipeline
    app.state.replay = replay
    app.include_router(router)

    @app.get("/")
    def root() -> dict[str, str]:
        return {
            "name": "TIPO",
            "expansion": "TIten POsko",
            "tagline": "Read the signs. Act first.",
            "docs": "/docs",
            "health": "/api/health",
        }

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=int(os.getenv("PORT", "8765")), reload=False)
