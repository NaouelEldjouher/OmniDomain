# api/routes/files.py

import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from api.db.session import get_db
from api.db.models import User
from api.db.repository import RunRepository, UploadRepository
from api.dependencies import get_current_user
from api.schemas import UploadResponse

log = logging.getLogger(__name__)
router = APIRouter()


@router.get("/{run_id}", response_model=list[UploadResponse])
def list_files(
        run_id: uuid.UUID,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user),
):
    """Return all uploaded files for a run."""
    run = RunRepository.get_by_id(db, run_id)
    if run is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Run {run_id} not found",
        )
    if run.user_id != current_user.user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not your run",
        )
    return UploadRepository.get_by_run(db, run_id)