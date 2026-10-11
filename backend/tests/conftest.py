import os
import tempfile

os.environ["TIPO_MODE"] = "mock"
os.environ["TIPO_REPLAY_SPEED"] = "0"
os.environ["TIPO_DATA_DIR"] = tempfile.mkdtemp(prefix="tipo-test-")
os.environ.pop("GOOGLE_API_KEY", None)
os.environ.pop("GEMINI_API_KEY", None)
os.environ.pop("GOOGLE_GENAI_USE_VERTEXAI", None)

import pytest
from fastapi.testclient import TestClient

from app.main import create_app


@pytest.fixture()
def client():
    app = create_app()
    with TestClient(app) as test_client:
        yield test_client
