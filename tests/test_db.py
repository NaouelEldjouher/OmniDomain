# tests/test_db.py
import sys
from pathlib import Path

# Add ui/ to path so imports work without 'ui.' prefix
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'ui'))

from core.db import get_or_create_user, create_run, get_user_runs


def test_create_new_user():
    user_id = get_or_create_user(email="bioinfo@example.com", name="Dr. Bio", org="Lab")
    assert user_id is not None
    assert isinstance(user_id, str)
    assert len(user_id) > 10


def test_returning_user_gets_same_id():
    first  = get_or_create_user(email="return@example.com")
    second = get_or_create_user(email="return@example.com")
    assert first == second


def test_create_and_fetch_run():
    user_id = get_or_create_user(email="researcher@university.edu")
    fake_tsv = {
        "sample":  "aspergillus_niger_01",
        "fastq_1": "s3://omni-compute/uploads/fungalflow/aspergillus_niger_01/R1.fastq.gz"
    }
    run_id = create_run(
        user_id=user_id,
        pipeline="FungalFlow",
        sample_id="aspergillus_niger_01",
        tsv_row=fake_tsv,
        base_outdir="s3://omni-results",
        cost_estimate=10.0
    )
    assert run_id is not None
    assert isinstance(run_id, str)

    runs = get_user_runs(user_id=user_id)
    assert len(runs) > 0
    latest = runs[0]
    assert latest["pipeline"]  == "FungalFlow"
    assert latest["sample_id"] == "aspergillus_niger_01"
    assert latest["status"]    == "CREATED"
