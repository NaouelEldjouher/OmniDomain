# tests/test_routes.py

from unittest.mock import patch, MagicMock


# ── Auth routes ───────────────────────────────────────────────────────────────

class TestAuthRoutes:

    def test_login_new_user(self, client):
        """POST /auth/login creates a new user and returns a token."""
        resp = client.post("/auth/login", json={
            "email": "new@lab.de",
            "name": "New Scientist",
            "org": "BioLab",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data
        assert data["email"] == "new@lab.de"
        assert data["token_type"] == "bearer"

    def test_login_returning_user(self, client):
        """Logging in twice with the same email returns the same user_id."""
        resp1 = client.post("/auth/login", json={"email": "return@lab.de"})
        resp2 = client.post("/auth/login", json={"email": "return@lab.de"})

        assert resp1.status_code == 200
        assert resp2.status_code == 200
        assert resp1.json()["user_id"] == resp2.json()["user_id"]

    def test_login_invalid_email(self, client):
        """POST /auth/login with an invalid email returns 422."""
        resp = client.post("/auth/login", json={"email": "not-an-email"})
        assert resp.status_code == 422

    def test_health_check(self, client):
        """GET /health returns 200 — no auth required."""
        resp = client.get("/health")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"


# ── Runs routes ───────────────────────────────────────────────────────────────

class TestRunsRoutes:

    def test_list_runs_requires_auth(self, client):
        """GET /runs without token returns 403."""
        resp = client.get("/runs/")
        assert resp.status_code in (401, 403)

    def test_list_runs_empty(self, client, auth_headers):
        """GET /runs returns empty list when user has no runs."""
        resp = client.get("/runs/", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json() == []

    def test_get_run_not_found(self, client, auth_headers):
        """GET /runs/{id} returns 404 for non-existent run."""
        import uuid
        resp = client.get(f"/runs/{uuid.uuid4()}", headers=auth_headers)
        assert resp.status_code == 404

    def test_create_run_submits_to_batch(self, client, auth_headers):
        """POST /runs creates a run and submits to Batch — Batch is mocked."""
        mock_resp = {"jobId": "aws-job-123", "jobName": "omni-nextamr-ecoli"}

        with patch("api.services.run_service.boto3") as mock_boto3:
            mock_batch = MagicMock()
            mock_batch.submit_job.return_value = mock_resp
            mock_boto3.client.return_value = mock_batch

            with patch("api.services.run_service.validate_structure", return_value=[]):
                resp = client.post("/runs/", headers=auth_headers, json={
                    "pipeline": "NextAMR",
                    "sample_id": "ecoli_01",
                    "tsv_row": {"sample_id": "ecoli_01"},
                    "base_outdir": "s3://omni-results",
                })

        assert resp.status_code == 201
        data = resp.json()
        assert data["pipeline"] == "NextAMR"
        assert data["sample_id"] == "ecoli_01"
        assert data["status"] == "SUBMITTED"
        assert data["job_id"] == "aws-job-123"

    def test_create_run_validation_error(self, client, auth_headers):
        """POST /runs with invalid TSV returns 422."""
        with patch("api.services.run_service.validate_structure",
                   return_value=["missing required column: illumina_r1"]):
            resp = client.post("/runs/", headers=auth_headers, json={
                "pipeline": "NextAMR",
                "sample_id": "ecoli_01",
                "tsv_row": {},
                "base_outdir": "s3://omni-results",
            })

        assert resp.status_code == 422
        assert "illumina_r1" in resp.json()["detail"]

    def test_create_run_batch_failure(self, client, auth_headers):
        """POST /runs returns 502 when AWS Batch submission fails."""
        with patch("api.services.run_service.boto3") as mock_boto3:
            mock_batch = MagicMock()
            mock_batch.submit_job.side_effect = Exception("Batch unavailable")
            mock_boto3.client.return_value = mock_batch

            with patch("api.services.run_service.validate_structure", return_value=[]):
                resp = client.post("/runs/", headers=auth_headers, json={
                    "pipeline": "NextAMR",
                    "sample_id": "ecoli_01",
                    "tsv_row": {},
                    "base_outdir": "s3://omni-results",
                })

        assert resp.status_code == 502