"""
OmniDomain — Database Client
SQLAlchemy + PostgreSQL
All database operations in one place.
"""
import os
import uuid
import json
from datetime import datetime, timezone
from typing import Optional, List, Dict
from contextlib import contextmanager
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base

# ── Connection Setup ──────────────────────────────────────────────────────────
DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()

_engine = None

def get_engine():
    global _engine
    if _engine is None:
        url = os.getenv("DATABASE_URL")
        _engine = create_engine(url, pool_pre_ping=True)
    return _engine

@contextmanager
def session():
    """Provides a transactional scope around a series of operations."""
    Session = sessionmaker(bind=get_engine())
    s = Session()
    try:
        yield s
        s.commit()
    except Exception:
        s.rollback()
        raise
    finally:
        s.close()


# ── Database Functions ────────────────────────────────────────────────────────

def get_or_create_user(email: str, name: str = None, org: str = None) -> str:
    """Return user_id for this email, creating user if first visit."""
    with session() as s:
        row = s.execute(
            text("SELECT user_id FROM users WHERE email = :email"),
            {"email": email}
        ).fetchone()

        if row:
            s.execute(
                text("UPDATE users SET last_login = NOW() WHERE email = :email"),
                {"email": email}
            )
            return str(row[0])

        user_id = str(uuid.uuid4())
        s.execute(
            text("""
                INSERT INTO users (user_id, email, name, org, created_at, last_login)
                VALUES (:uid, :email, :name, :org, NOW(), NOW())
            """),
            {"uid": user_id, "email": email, "name": name, "org": org}
        )
        return user_id


def create_run(user_id: str, pipeline: str, sample_id: str,
               tsv_row: dict, base_outdir: str,
               cost_estimate: float = None) -> str:
    """Create run record before AWS Batch submission."""
    run_id = str(uuid.uuid4())
    with session() as s:
        s.execute(
            text("""
                INSERT INTO runs
                    (run_id, user_id, pipeline, sample_id,
                     tsv_row, base_outdir, cost_estimate, status)
                VALUES
                    (:run_id, :uid, :pipeline, :sample_id,
                     CAST(:tsv_row AS json), :outdir, :cost, 'CREATED')
            """),
            {
                "run_id": run_id, "uid": user_id,
                "pipeline": pipeline, "sample_id": sample_id,
                "tsv_row": json.dumps(tsv_row),
                "outdir": base_outdir, "cost": cost_estimate,
            }
        )
        _log_status(s, run_id, "CREATED")
    return run_id


def get_user_runs(user_id: str) -> List[Dict]:
    """All runs for a user, newest first."""
    with session() as s:
        rows = s.execute(
            text("""
                SELECT run_id, pipeline, sample_id, status,
                       cost_estimate, base_outdir
                FROM runs
                WHERE user_id = :uid
            """),
            {"uid": user_id}
        ).fetchall()
        return [dict(r._mapping) for r in rows]


def _log_status(s, run_id: str, status: str, message: str = None):
    """Insert status history row — always called inside existing session."""
    log_id = str(uuid.uuid4())
    s.execute(
        text("""
            INSERT INTO run_status_history (log_id, run_id, status, message)
            VALUES (:log_id, :run_id, :status, :message)
        """),
        {"log_id": log_id, "run_id": run_id, "status": status, "message": message}
    )

def mark_submitted(run_id: str, job_id: str, job_name: str, resume: bool = False):
    """Update run status to SUBMITTED after AWS Batch job created."""
    with session() as s:
        s.execute(
            text("""
                UPDATE runs SET
                    status = 'SUBMITTED',
                    job_id = :job_id,
                    job_name = :job_name,
                    submitted_at = NOW()
                WHERE run_id = :run_id
            """),
            {"run_id": run_id, "job_id": job_id, "job_name": job_name}
        )
        _log_status(s, run_id, "SUBMITTED", f"job_id={job_id}")


def update_status(run_id: str, status: str, message: str = None):
    """Update run status — called by monitor tab polling AWS Batch."""
    with session() as s:
        completed = status in ("SUCCEEDED", "FAILED")
        s.execute(
            text("""
                UPDATE runs SET
                    status = :status,
                    completed_at = CASE WHEN :completed THEN NOW() ELSE completed_at END
                WHERE run_id = :run_id
            """),
            {"run_id": run_id, "status": status, "completed": completed}
        )
        _log_status(s, run_id, status, message)


def record_upload(run_id: str, filename: str, s3_uri: str, size_bytes: int):
    """Track individual file uploads for audit trail."""
    upload_id = str(uuid.uuid4())
    with session() as s:
        s.execute(
            text("""
                INSERT INTO uploads
                    (upload_id, run_id, filename, s3_uri, size_bytes, uploaded_at)
                VALUES
                    (:upload_id, :run_id, :filename, :s3_uri, :size_bytes, NOW())
            """),
            {"upload_id": upload_id, "run_id": run_id,
             "filename": filename, "s3_uri": s3_uri, "size_bytes": size_bytes}
        )
