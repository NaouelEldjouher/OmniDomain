# api/routes/auth.py

import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from api.db.session import get_db
from api.schemas import LoginRequest, TokenResponse
from api.services.auth_service import login_or_register

log = logging.getLogger(__name__)
router = APIRouter()


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    """
    Email-only login for internal scientific tooling.
    Creates the user on first visit, returns a JWT token.
    """
    try:
        user, token = login_or_register(db, body.email, body.name, body.org)
        return TokenResponse(
            access_token=token,
            user_id=str(user.user_id),
            email=user.email,
        )
    except Exception as e:
        log.exception("Login failed for %s", body.email)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Login failed",
        )