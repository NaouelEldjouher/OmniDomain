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