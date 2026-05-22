# core/models.py
from core.db import Base
from sqlalchemy import Column, String, Float, JSON, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import UUID
import uuid

class User(Base):
    __tablename__ = 'users'
    user_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False)
    name = Column(String(255))
    org = Column(String(255))
    created_at = Column(DateTime)
    last_login = Column(DateTime)

class Run(Base):
    __tablename__ = 'runs'
    run_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID, ForeignKey('users.user_id'))
    pipeline = Column(String(50))
    sample_id = Column(String(100))
    status = Column(String(50))
    tsv_row = Column(JSON)
    base_outdir = Column(String(255))
    cost_estimate = Column(Float)

class RunStatusHistory(Base):
    __tablename__ = 'run_status_history'
    log_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    run_id = Column(UUID, ForeignKey('runs.run_id'))
    status = Column(String(50))
    message = Column(String)