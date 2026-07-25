# TODO: pytest tests using FastAPI TestClient
#
# Worth testing:
# - health check returns 200
# - shorten_url returns 201 and a valid short_code
# - redirect works and increments the click counter
# - unknown short_code returns 404
# - invalid URL in /shorten returns 422
#
# Hint: use a separate DB for tests (e.g. in-memory SQLite) via
# app.dependency_overrides[get_db], so you're not testing against the production Postgres.

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app

TEST_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

client = TestClient(app)


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200


def test_shorten_url():
    response = client.post("/shorten", json={"target_url": "https://example.com"})
    assert response.status_code == 201
    data = response.json()
    assert len(data["short_code"]) == 6
    assert data["clicks"] == 0


def test_redirect_and_click_count():
    create_resp = client.post("/shorten", json={"target_url": "https://example.com"})
    code = create_resp.json()["short_code"]

    redirect_resp = client.get(f"/{code}", follow_redirects=False)
    assert redirect_resp.status_code == 307

    stats_resp = client.get(f"/stats/{code}")
    assert stats_resp.json()["clicks"] == 1


def test_unknown_code_return_404():
    check_url = client.get(
        "/doesnotexist",
    )
    assert check_url.status_code == 404


def test_invalid_url_rejeceted():
    check_url = client.post("/shorten", json={"target_url": "not-a-url"})
    assert check_url.status_code == 422


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)
