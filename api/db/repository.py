# api/db/repository.py

import logging
import uuid
from datetime import datetime
from typing import List, Optional

from sqlalchemy import select, update, desc
from sqlalchemy.orm import Session

from api.db.models import Run, User, Upload, RunStatusHistory, RunStatus

log = logging.getLogger(__name__)


# ── User ─────────────────────────────────────────────────────────────────────

class UserRepository:

    @staticmethod
    def get_by_email(db: Session, email: str) -> Optional[User]:
        log.debug("get_by_email: %s", email)
        return db.execute(
            select(User).where(User.email == email)
        ).scalar_one_or_none()

    @staticmethod
    def create(db: Session, email: str, name: Optional[str], org: Optional[str]) -> User:
        log.debug("create user: %s", email)
        user = User(
            user_id=uuid.uuid4(),
            email=email,
            name=name,
            org=org,
        )
        db.add(user)
        db.flush()
        log.info("user created: %s", user.user_id)
        return user

    @staticmethod
    def update_last_login(db: Session, user_id: uuid.UUID) -> None:
        log.debug("update_last_login: %s", user_id)
        db.execute(
            update(User)
            .where(User.user_id == user_id)
            .values(last_login=datetime.utcnow())
        )


# ── Run ───────────────────────────────────────────────────────────────────────

class RunRepository:

    @staticmethod
    def create(
        db: Session,
        user_id: uuid.UUID,
        pipeline: str,
        sample_id: str,
        tsv_row: dict,
        base_outdir: str,
        cost_estimate: Optional[float] = None,
    ) -> Run:
        log.debug("create run: user=%s pipeline=%s sample=%s", user_id, pipeline, sample_id)
        run = Run(
            run_id=uuid.uuid4(),
            user_id=user_id,
            pipeline=pipeline,
            sample_id=sample_id,
            tsv_row=tsv_row,
            base_outdir=base_outdir,
            cost_estimate=cost_estimate,
            status=RunStatus.CREATED,
        )
        db.add(run)
        db.flush()
        RunRepository._log_status(db, run.run_id, RunStatus.CREATED)
        log.info("run created: %s", run.run_id)
        return run

    @staticmethod
    def get_by_id(db: Session, run_id: uuid.UUID) -> Optional[Run]:
        return db.execute(
            select(Run).where(Run.run_id == run_id)
        ).scalar_one_or_none()

    @staticmethod
    def get_by_user(db: Session, user_id: uuid.UUID) -> List[Run]:
        return db.execute(
            select(Run)
            .where(Run.user_id == user_id)
            .order_by(desc(Run.created_at))
        ).scalars().all()

    @staticmethod
    def get_active(db: Session) -> List[Run]:
        """All runs currently in a non-terminal state — used by the monitor."""
        return db.execute(
            select(Run).where(
                Run.status.in_([
                    RunStatus.SUBMITTED,
                    RunStatus.RUNNING,
                ])
            )
        ).scalars().all()

    @staticmethod
    def mark_submitted(
        db: Session,
        run_id: uuid.UUID,
        job_id: str,
        job_name: str,
    ) -> None:
        log.debug("mark_submitted: run=%s job=%s", run_id, job_id)
        db.execute(
            update(Run)
            .where(Run.run_id == run_id)
            .values(
                status=RunStatus.SUBMITTED,
                job_id=job_id,
                job_name=job_name,
                submitted_at=datetime.utcnow(),
            )
        )
        RunRepository._log_status(db, run_id, RunStatus.SUBMITTED, f"job_id={job_id}")

    @staticmethod
    def update_status(
        db: Session,
        run_id: uuid.UUID,
        status: RunStatus,
        message: Optional[str] = None,
    ) -> None:
        log.debug("update_status: run=%s status=%s", run_id, status)
        values = {"status": status}
        if status in (RunStatus.COMPLETED, RunStatus.FAILED):
            values["completed_at"] = datetime.utcnow()
        db.execute(
            update(Run)
            .where(Run.run_id == run_id)
            .values(**values)
        )
        RunRepository._log_status(db, run_id, status, message)

    @staticmethod
    def _log_status(
        db: Session,
        run_id: uuid.UUID,
        status: RunStatus,
        message: Optional[str] = None,
    ) -> None:
        """Internal only — always called inside an existing transaction."""
        db.add(RunStatusHistory(
            log_id=uuid.uuid4(),
            run_id=run_id,
            status=status,
            message=message,
        ))


# ── Upload ────────────────────────────────────────────────────────────────────

class UploadRepository:

    @staticmethod
    def record(
        db: Session,
        run_id: uuid.UUID,
        filename: str,
        s3_uri: str,
        size_bytes: Optional[int] = None,
    ) -> Upload:
        log.debug("record upload: run=%s file=%s", run_id, filename)
        upload = Upload(
            upload_id=uuid.uuid4(),
            run_id=run_id,
            filename=filename,
            s3_uri=s3_uri,
            size_bytes=size_bytes,
        )
        db.add(upload)
        db.flush()
        return upload

    @staticmethod
    def get_by_run(db: Session, run_id: uuid.UUID) -> List[Upload]:
        return db.execute(
            select(Upload).where(Upload.run_id == run_id)
        ).scalars().all()