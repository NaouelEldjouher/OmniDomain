import uuid
from datetime import datetime
from enum import Enum as PyEnum
from typing import List, Optional, Any

from sqlalchemy import String, Float, ForeignKey, DateTime, Integer, Boolean, Enum
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship, Mapped, mapped_column
from sqlalchemy.sql import func

from api.db.session import Base


class RunStatus(str, PyEnum):
    CREATED = "CREATED"
    SUBMITTED = "SUBMITTED"
    RUNNING = "RUNNING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[Optional[str]] = mapped_column(String(255))
    org: Mapped[Optional[str]] = mapped_column(String(255))

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    last_login: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    runs: Mapped[List["Run"]] = relationship(
        "Run", back_populates="user", cascade="all, delete-orphan"
    )


class Run(Base):
    __tablename__ = "runs"

    run_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"), index=True
    )

    pipeline: Mapped[str] = mapped_column(String(50), index=True)
    sample_id: Mapped[str] = mapped_column(String(100))

    status: Mapped[RunStatus] = mapped_column(
        Enum(RunStatus, name="run_status_enum"), default=RunStatus.CREATED, index=True
    )

    tsv_row: Mapped[Optional[dict[str, Any]]] = mapped_column(JSONB)

    base_outdir: Mapped[Optional[str]] = mapped_column(String(255))
    cost_estimate: Mapped[Optional[float]] = mapped_column(Float)
    job_id: Mapped[Optional[str]] = mapped_column(String(255))
    job_name: Mapped[Optional[str]] = mapped_column(String(255))

    submitted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    resume: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    user: Mapped["User"] = relationship("User", back_populates="runs")
    uploads: Mapped[List["Upload"]] = relationship(
        "Upload", back_populates="run", cascade="all, delete-orphan"
    )
    status_history: Mapped[List["RunStatusHistory"]] = relationship(
        "RunStatusHistory",
        back_populates="run",
        order_by="RunStatusHistory.created_at",
        cascade="all, delete-orphan",
    )


class Upload(Base):
    """
    Represents a single pipeline execution for one sample.
    One user can have many runs. Each run has an audit trail
    in RunStatusHistory and file records in Upload.
    """

    __tablename__ = "uploads"

    upload_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    run_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("runs.run_id", ondelete="CASCADE"), index=True
    )
    filename: Mapped[str] = mapped_column(String(255))
    s3_uri: Mapped[str] = mapped_column(String(500))
    size_bytes: Mapped[Optional[int]] = mapped_column(Integer)
    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    run: Mapped["Run"] = relationship("Run", back_populates="uploads")


class RunStatusHistory(Base):
    """
    Append-only audit trail for run status transitions.
    Never updated, only inserted. Ordered by created_at.
    """

    __tablename__ = "run_status_history"

    log_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    run_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("runs.run_id", ondelete="CASCADE"), index=True
    )

    status: Mapped[RunStatus] = mapped_column(Enum(RunStatus, name="run_status_enum"))
    message: Mapped[Optional[str]] = mapped_column(String)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    run: Mapped["Run"] = relationship("Run", back_populates="status_history")
