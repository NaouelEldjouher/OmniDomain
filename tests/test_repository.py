# tests/test_repository.py

import uuid
import pytest
from api.db.repository import UserRepository, RunRepository, UploadRepository
from api.db.models import RunStatus


# ── UserRepository ────────────────────────────────────────────────────────────

class TestUserRepository:

    def test_create_user(self, db):
        """Creating a user returns a User object with correct fields."""
        user = UserRepository.create(db, "bio@lab.de", "Dr. Bio", "BioLab")
        db.commit()

        assert user.user_id is not None
        assert user.email == "bio@lab.de"
        assert user.name == "Dr. Bio"
        assert user.org == "BioLab"

    def test_get_by_email_found(self, db):
        """get_by_email returns the user when email exists."""
        UserRepository.create(db, "found@lab.de", "Found", "Lab")
        db.commit()

        result = UserRepository.get_by_email(db, "found@lab.de")
        assert result is not None
        assert result.email == "found@lab.de"

    def test_get_by_email_not_found(self, db):
        """get_by_email returns None when email does not exist."""
        result = UserRepository.get_by_email(db, "nobody@lab.de")
        assert result is None

    def test_create_user_without_optional_fields(self, db):
        """Name and org are optional — user can be created with email only."""
        user = UserRepository.create(db, "minimal@lab.de", None, None)
        db.commit()

        assert user.email == "minimal@lab.de"
        assert user.name is None
        assert user.org is None

    def test_duplicate_email_raises(self, db):
        """Creating two users with the same email raises an integrity error."""
        UserRepository.create(db, "dup@lab.de", "First", "Lab")
        db.commit()

        with pytest.raises(Exception):  # IntegrityError from unique constraint
            UserRepository.create(db, "dup@lab.de", "Second", "Lab")
            db.commit()


# ── RunRepository ─────────────────────────────────────────────────────────────

class TestRunRepository:

    @pytest.fixture
    def user(self, db):
        u = UserRepository.create(db, "runner@lab.de", "Runner", "Lab")
        db.commit()
        return u

    def test_create_run(self, db, user):
        """Creating a run returns a Run object with status CREATED."""
        run = RunRepository.create(
            db,
            user_id=user.user_id,
            pipeline="NextAMR",
            sample_id="ecoli_01",
            tsv_row={"sample_id": "ecoli_01"},
            base_outdir="s3://omni-results",
        )
        db.commit()

        assert run.run_id is not None
        assert run.pipeline == "NextAMR"
        assert run.sample_id == "ecoli_01"
        assert run.status == RunStatus.CREATED

    def test_create_run_writes_status_history(self, db, user):
        """Creating a run automatically writes a CREATED status history entry."""
        run = RunRepository.create(
            db,
            user_id=user.user_id,
            pipeline="NextAMR",
            sample_id="ecoli_01",
            tsv_row={},
            base_outdir="s3://omni-results",
        )
        db.commit()

        # access the audit trail
        history = run.status_history
        assert len(history) == 1
        assert history[0].status == RunStatus.CREATED

    def test_get_by_id_found(self, db, user):
        """get_by_id returns the run when it exists."""
        run = RunRepository.create(
            db, user_id=user.user_id, pipeline="NextAMR",
            sample_id="s1", tsv_row={}, base_outdir="s3://omni-results",
        )
        db.commit()

        result = RunRepository.get_by_id(db, run.run_id)
        assert result is not None
        assert result.run_id == run.run_id

    def test_get_by_id_not_found(self, db):
        """get_by_id returns None for a non-existent run_id."""
        result = RunRepository.get_by_id(db, uuid.uuid4())
        assert result is None

    def test_get_by_user_returns_newest_first(self, db, user):
        """get_by_user returns runs ordered newest first."""
        run1 = RunRepository.create(
            db, user_id=user.user_id, pipeline="NextAMR",
            sample_id="s1", tsv_row={}, base_outdir="s3://omni-results",
        )
        run2 = RunRepository.create(
            db, user_id=user.user_id, pipeline="FungalFlow",
            sample_id="s2", tsv_row={}, base_outdir="s3://omni-results",
        )
        db.commit()

        runs = RunRepository.get_by_user(db, user.user_id)
        assert len(runs) == 2
        # newest first — run2 was created after run1
        assert runs[0].sample_id == "s2"
        assert runs[1].sample_id == "s1"

    def test_get_active_returns_only_active(self, db, user):
        """get_active only returns SUBMITTED and RUNNING runs."""
        created = RunRepository.create(
            db, user_id=user.user_id, pipeline="NextAMR",
            sample_id="created", tsv_row={}, base_outdir="s3://omni-results",
        )
        submitted = RunRepository.create(
            db, user_id=user.user_id, pipeline="NextAMR",
            sample_id="submitted", tsv_row={}, base_outdir="s3://omni-results",
        )
        db.commit()

        RunRepository.mark_submitted(db, submitted.run_id, "job-123", "omni-job")
        db.commit()

        active = RunRepository.get_active(db)
        active_ids = [r.run_id for r in active]

        assert submitted.run_id in active_ids
        assert created.run_id not in active_ids  # CREATED is not active

    def test_mark_submitted(self, db, user):
        """mark_submitted updates status and records job_id."""
        run = RunRepository.create(
            db, user_id=user.user_id, pipeline="NextAMR",
            sample_id="s1", tsv_row={}, base_outdir="s3://omni-results",
        )
        db.commit()

        RunRepository.mark_submitted(db, run.run_id, "aws-job-456", "omni-nextamr-s1")
        db.commit()

        updated = RunRepository.get_by_id(db, run.run_id)
        assert updated.status == RunStatus.SUBMITTED
        assert updated.job_id == "aws-job-456"
        assert updated.submitted_at is not None

    def test_update_status_to_failed_sets_completed_at(self, db, user):
        """Updating status to FAILED sets completed_at."""
        run = RunRepository.create(
            db, user_id=user.user_id, pipeline="NextAMR",
            sample_id="s1", tsv_row={}, base_outdir="s3://omni-results",
        )
        db.commit()

        RunRepository.update_status(db, run.run_id, RunStatus.FAILED, "OOM error")
        db.commit()

        updated = RunRepository.get_by_id(db, run.run_id)
        assert updated.status == RunStatus.FAILED
        assert updated.completed_at is not None

    def test_update_status_to_running_does_not_set_completed_at(self, db, user):
        """Updating status to RUNNING does not set completed_at."""
        run = RunRepository.create(
            db, user_id=user.user_id, pipeline="NextAMR",
            sample_id="s1", tsv_row={}, base_outdir="s3://omni-results",
        )
        db.commit()

        RunRepository.update_status(db, run.run_id, RunStatus.RUNNING)
        db.commit()

        updated = RunRepository.get_by_id(db, run.run_id)
        assert updated.status == RunStatus.RUNNING
        assert updated.completed_at is None

    def test_status_history_is_append_only(self, db, user):
        """Every status change adds a history entry — never overwrites."""
        run = RunRepository.create(
            db, user_id=user.user_id, pipeline="NextAMR",
            sample_id="s1", tsv_row={}, base_outdir="s3://omni-results",
        )
        db.commit()

        RunRepository.mark_submitted(db, run.run_id, "job-1", "name-1")
        RunRepository.update_status(db, run.run_id, RunStatus.RUNNING)
        RunRepository.update_status(db, run.run_id, RunStatus.COMPLETED)
        db.commit()

        history = run.status_history
        statuses = [h.status for h in history]

        assert RunStatus.CREATED in statuses
        assert RunStatus.SUBMITTED in statuses
        assert RunStatus.RUNNING in statuses
        assert RunStatus.COMPLETED in statuses
        assert len(history) == 4  # one entry per transition


# ── UploadRepository ──────────────────────────────────────────────────────────

class TestUploadRepository:

    @pytest.fixture
    def run(self, db):
        user = UserRepository.create(db, "uploader@lab.de", "Up", "Lab")
        db.commit()
        r = RunRepository.create(
            db, user_id=user.user_id, pipeline="NextAMR",
            sample_id="s1", tsv_row={}, base_outdir="s3://omni-results",
        )
        db.commit()
        return r

    def test_record_upload(self, db, run):
        """Recording an upload returns an Upload object."""
        upload = UploadRepository.record(
            db, run.run_id, "ecoli_R1.fastq.gz",
            "s3://omni-compute/uploads/ecoli_R1.fastq.gz", 1024
        )
        db.commit()

        assert upload.upload_id is not None
        assert upload.filename == "ecoli_R1.fastq.gz"
        assert upload.size_bytes == 1024

    def test_get_by_run(self, db, run):
        """get_by_run returns all uploads for a run."""
        UploadRepository.record(db, run.run_id, "file1.fastq.gz", "s3://bucket/f1", 100)
        UploadRepository.record(db, run.run_id, "file2.fastq.gz", "s3://bucket/f2", 200)
        db.commit()

        uploads = UploadRepository.get_by_run(db, run.run_id)
        assert len(uploads) == 2