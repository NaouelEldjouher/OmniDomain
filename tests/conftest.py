# tests/conftest.py


import os
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from api.db.session import Base
from api.main import app
from api.db.session import get_db


# ── Test database ─────────────────────────────────────────────────────────────

def get_test_db_url() -> str:
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise RuntimeError(
            "DATABASE_URL is not set. "
            "Run: export DATABASE_URL=postgresql://omni:omnipass@localhost/omnidb"
        )
    return url

@pytest.fixture(scope="function")
def db():
    """
    Fresh in-memory SQLite database for each test.
    Creates all tables, yields a session, tears down after.
    scope="function" means each test gets a clean database.
    """
    engine = create_engine(get_test_db_url())
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(engine)
        engine.dispose()


@pytest.fixture(scope="function")
def client(db):
    """
    FastAPI TestClient with the test database injected.
    Overrides get_db() dependency so the API uses the test database.
    """
    def override_get_db():
        try:
            yield db
        finally:
            pass  # session lifecycle managed by db fixture

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture
def test_user(db):
    """A pre-created user for tests that need one."""
    from api.db.repository import UserRepository
    user = UserRepository.create(db, "scientist@lab.de", "Dr. Test", "TestLab")
    db.commit()
    return user




@pytest.fixture
def auth_headers(client) -> dict:
    """Login and return Authorization headers for authenticated requests."""
    resp = client.post("/auth/login", json={
        "email": "scientist@lab.de",
        "name": "Dr. Test",
        "org": "TestLab",
    })
    assert resp.status_code == 200
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}