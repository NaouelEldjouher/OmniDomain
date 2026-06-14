# api/services/auth_service.py

import os
import logging
from datetime import datetime, timedelta, timezone

import jwt
from sqlalchemy.orm import Session

from api.db.models import User
from api.db.repository import UserRepository

log = logging.getLogger(__name__)

# ── Config ────────────────────────────────────────────────────────────────────
JWT_SECRET = os.environ.get("JWT_SECRET", "dev-secret-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_HOURS = 24


# ── Token creation ────────────────────────────────────────────────────────────

def create_token(user: User) -> str:
    """Create a JWT token for the given user."""
    payload = {
        "sub": str(user.user_id),
        "email": user.email,
        "exp": datetime.now(timezone.utc) + timedelta(hours=JWT_EXPIRE_HOURS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_token(token: str) -> dict:
    """Decode and validate a JWT token. Raises jwt.InvalidTokenError if invalid."""
    return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])


# ── Login flow ────────────────────────────────────────────────────────────────

def login_or_register(
        db: Session,
        email: str,
        name: str | None = None,
        org: str | None = None,
) -> tuple[User, str]:
    """
    Get or create a user, update last_login, return (user, token).
    This is email-only auth — no password needed for internal tooling.
    """
    user = UserRepository.get_by_email(db, email)

    if user is None:
        log.info("New user registering: %s", email)
        user = UserRepository.create(db, email, name, org)
    else:
        log.info("Returning user: %s", email)
        UserRepository.update_last_login(db, user.user_id)

    db.commit()

    token = create_token(user)
    return user, token