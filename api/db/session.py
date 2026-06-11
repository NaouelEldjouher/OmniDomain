"""
Core database session management.

Handles database connection pooling, engine initialization,
and session lifecycle for FastAPI dependency injection.
"""
from __future__ import annotations

import logging
import os
from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, declarative_base, sessionmaker
from sqlalchemy.pool import QueuePool

# 1. Initialize Logger
logger = logging.getLogger(__name__)

# 2. Module-Level Constants
# Extracting magic numbers makes it easier to tune these later
POOL_SIZE = 5
MAX_OVERFLOW = 10
POOL_TIMEOUT = 30

# 3. Base class for SQLAlchemy Models
Base = declarative_base()


def _build_engine() -> Engine:
    """Constructs and returns a SQLAlchemy engine with connection pooling."""
    url = os.getenv("DATABASE_URL")

    # 4. Guard clause with a CRITICAL log
    if not url:
        # If the DB URL is missing, the app is fundamentally broken.
        logger.critical("DATABASE_URL is missing. Cannot start application.")
        raise RuntimeError(
            "DATABASE_URL is not set. "
            "Check your .env file or Secrets Manager."
        )

    logger.info("Initializing database connection pool...")

    return create_engine(
        url,
        poolclass=QueuePool,
        pool_size=POOL_SIZE,
        max_overflow=MAX_OVERFLOW,
        pool_timeout=POOL_TIMEOUT,
        pool_pre_ping=True,
    )


# 5. Global engine and session factory

engine = _build_engine()
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)


def get_db() -> Generator[Session, None, None]:
    """
    FastAPI dependency that provides a clean database session per request.
    Ensures the connection is always returned to the pool, even if an error occurs.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()