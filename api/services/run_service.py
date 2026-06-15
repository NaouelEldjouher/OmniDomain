# api/services/run_service.py

import logging
import os
from typing import Optional

import boto3
from sqlalchemy.orm import Session

from api.db.models import Run, RunStatus
from api.db.repository import RunRepository
from ui.core.nextflow_builder import build_command
from ui.core.validator import validate_structure

log = logging.getLogger(__name__)

# ── Config ────────────────────────────────────────────────────────────────────
AWS_BATCH_JOB_DEF = os.environ.get("AWS_BATCH_JOB_DEFINITION", "omni-nextflow-job")
AWS_BATCH_QUEUE = os.environ.get("AWS_BATCH_QUEUE", "omni-batch-queue")
AWS_REGION = os.environ.get("AWS_REGION", "eu-central-1")


# ── Service functions ─────────────────────────────────────────────────────────

def create_run(
        db: Session,
        user_id,
        pipeline: str,
        sample_id: str,
        tsv_row: dict,
        base_outdir: str,
        cost_estimate: Optional[float] = None,
) -> Run:
    """
    Validate inputs and create a run record.
    Does NOT submit to Batch — call submit_run() for that.
    Commits the transaction.
    """
    # validate scientific inputs before touching the database
    errors = validate_structure(tsv_row, pipeline)
    if errors:
        raise ValueError(f"Validation failed: {'; '.join(errors)}")

    run = RunRepository.create(
        db,
        user_id=user_id,
        pipeline=pipeline,
        sample_id=sample_id,
        tsv_row=tsv_row,
        base_outdir=base_outdir,
        cost_estimate=cost_estimate,
    )
    db.commit()
    log.info("Run created: %s pipeline=%s sample=%s", run.run_id, pipeline, sample_id)
    return run


def submit_run(db: Session, run: Run, resume: bool = False) -> Run:
    """
    Submit an existing run to AWS Batch.
    Updates run status to SUBMITTED on success.
    Commits the transaction.
    Raises RuntimeError if Batch submission fails.
    """
    import pandas as pd
    row = pd.Series(run.tsv_row)
    cmd = build_command(run.pipeline, row, resume=resume)

    job_name = f"omni-{run.pipeline.lower()}-{run.sample_id}"

    try:
        batch = boto3.client("batch", region_name=AWS_REGION)
        resp = batch.submit_job(
            jobName=job_name,
            jobQueue=AWS_BATCH_QUEUE,
            jobDefinition=AWS_BATCH_JOB_DEF,
            containerOverrides={"command": ["bash", "-c", cmd]},
            tags={
                "pipeline": run.pipeline,
                "sample_id": run.sample_id,
                "run_id": str(run.run_id),
            },
        )
    except Exception as e:
        log.exception("Batch submission failed for run %s", run.run_id)
        raise RuntimeError(f"AWS Batch submission failed: {e}") from e

    RunRepository.mark_submitted(db, run.run_id, resp["jobId"], job_name)
    db.commit()
    log.info("Run submitted: %s job_id=%s", run.run_id, resp["jobId"])
    return run


def get_user_runs(db: Session, user_id) -> list[Run]:
    """Return all runs for a user, newest first."""
    return RunRepository.get_by_user(db, user_id)


def update_run_status(
        db: Session,
        run_id,
        status: RunStatus,
        message: Optional[str] = None,
) -> None:
    """Update run status — called by monitor polling AWS Batch."""
    RunRepository.update_status(db, run_id, status, message)
    db.commit()