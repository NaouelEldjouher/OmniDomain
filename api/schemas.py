# api/schemas.py

import uuid
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr
from api.db.models import RunStatus


# ── Auth ──────────────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    email: EmailStr
    name: Optional[str] = None
    org: Optional[str] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    email: str


# ── Runs ──────────────────────────────────────────────────────────────────────

class RunCreate(BaseModel):
    pipeline: str
    sample_id: str
    tsv_row: dict
    base_outdir: str = "s3://omni-results"
    cost_estimate: Optional[float] = None
    resume: bool = False


class RunSubmit(BaseModel):
    run_id: uuid.UUID


class RunResponse(BaseModel):
    run_id: uuid.UUID
    pipeline: str
    sample_id: str
    status: RunStatus
    cost_estimate: Optional[float]
    base_outdir: str
    job_id: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class RunStatusUpdate(BaseModel):
    status: RunStatus
    message: Optional[str] = None


# ── Uploads ───────────────────────────────────────────────────────────────────

class UploadResponse(BaseModel):
    upload_id: uuid.UUID
    filename: str
    s3_uri: str
    size_bytes: Optional[int]
    uploaded_at: datetime

    class Config:
        from_attributes = True