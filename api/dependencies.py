# api/dependencies.py

import logging
import uuid

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from api.db.session import get_db
from api.db.models import User
from api.db.repository import UserRepository
from api.services.auth_service import decode_token

log = logging.getLogger(__name__)

bearer_scheme = HTTPBearer()


def get_current_user(
        credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
        db: Session = Depends(get_db),
) -> User:
    """
    FastAPI dependency — validates JWT token and returns the current user.
    Add to any route that requires authentication:
        user = Depends(get_current_user)
    """
    token = credentials.credentials
    try:
        payload = decode_token(token)
        user_id = uuid.UUID(payload["sub"])
    except (jwt.InvalidTokenError, KeyError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = UserRepository.get_by_email(db, payload["email"])
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    return user