# tests/test_db.py
import sys
from pathlib import Path
from ui.core.db import get_or_create_user, create_run, get_user_runs

# 1. Point Python to your app code
sys.path.append(str(Path(__file__).resolve().parent.parent))

from ui.core.db import get_or_create_user


# 2. Write the tests
def test_create_new_user():
    # Arrange (Set up the data)
    test_email = "bioinfo@example.com"

    # Act (Run the function you want to test)
    user_id = get_or_create_user(email=test_email, name="Dr. Bio", org="Lab")

    # Assert (Verify the output is exactly what you expect)
    assert user_id is not None
    assert type(user_id) == str
    assert len(user_id) > 10  # It's a UUID, so it should be long


def test_returning_user_gets_same_id():
    # Arrange
    test_email = "return@example.com"

    # Act
    first_login_id = get_or_create_user(email=test_email)
    second_login_id = get_or_create_user(email=test_email)

    # Assert
    assert first_login_id == second_login_id


# Add this import to the top of tests/test_db.py
from ui.core.db import get_or_create_user, create_run, get_user_runs


# Add this new test at the bottom of the file
def test_create_and_fetch_run():
    # Arrange: Create a user and some fake biological data
    test_email = "researcher@university.edu"
    user_id = get_or_create_user(email=test_email)

    fake_tsv = {
        "sample": "tumor_01",
        "fastq_1": "s3://raw-data/tumor_01_R1.fastq.gz"
    }

    # Act: Create the run
    run_id = create_run(
        user_id=user_id,
        pipeline="nf-core/rnaseq",
        sample_id="tumor_01",
        tsv_row=fake_tsv,
        base_outdir="s3://results/tumor_01/",
        cost_estimate=3.50
    )

    # Assert 1: The function returned a valid UUID string
    assert run_id is not None
    assert type(run_id) == str

    # Assert 2: We can fetch the run back from the database
    user_runs = get_user_runs(user_id=user_id)

    # Make sure we got at least one run back
    assert len(user_runs) > 0

    # Check that the most recent run matches our data
    latest_run = user_runs[0]
    assert latest_run["pipeline"] == "nf-core/rnaseq"
    assert latest_run["sample_id"] == "tumor_01"
    assert latest_run["status"] == "CREATED"