# api/routes/runs.py

import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from api.db.session import get_db
from api.db.models import User
from api.dependencies import get_current_user
from api.schemas import RunCreate, RunResponse
from api.services import run_service

log = logging.getLogger(__name__)
router = APIRouter()


@router.post("/", response_model=RunResponse, status_code=status.HTTP_201_CREATED)
def create_run(
        body: RunCreate,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user),
):
    """
    Create a new run record and submit to AWS Batch.
    Requires a valid JWT token.
    """
    try:
        run = run_service.create_run(
            db,
            user_id=current_user.user_id,
            pipeline=body.pipeline,
            sample_id=body.sample_id,
            tsv_row=body.tsv_row,
            base_outdir=body.base_outdir,
            cost_estimate=body.cost_estimate,
        )
        run = run_service.submit_run(db, run, resume=body.resume)
        return run

    except ValueError as e:
        # validation error — bad input from scientist
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e),
        )
    except RuntimeError as e:
        # AWS Batch submission failed
        log.exception("Batch submission failed")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(e),
        )
    except Exception as e:
        log.exception("Unexpected error creating run")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error",
        )


@router.get("/", response_model=list[RunResponse])
def list_runs(
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user),
):
    """Return all runs for the current user, newest first."""
    return run_service.get_user_runs(db, current_user.user_id)


@router.get("/{run_id}", response_model=RunResponse)
def get_run(
        run_id: uuid.UUID,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user),
):
    """Return a single run by ID."""
    from api.db.repository import RunRepository
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
    return run