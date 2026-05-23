# tests/test_nextflow.py
import sys
from pathlib import Path
import pandas as pd

sys.path.append(str(Path(__file__).resolve().parent.parent))

from ui.core.nextflow_builder import build_command


def test_fungalflow_command_generation():
    # Arrange: Create a fake TSV row using pandas, exactly as the app would
    pipeline = "FungalFlow"
    fake_tsv_row = pd.Series({
        "sample_id": "fungal_sample_01",
        "shortreads_r1": "s3://bucket/reads_R1.fastq.gz",
        "shortreads_r2": "s3://bucket/reads_R2.fastq.gz",
        "longreads": "s3://bucket/pacbio.fastq.gz"
    })

    # Act: Generate the Nextflow command
    cmd = build_command(pipeline=pipeline, row=fake_tsv_row)

    # Assert: Verify the string contains all the correct dynamic flags
    assert "nextflow run" in cmd
    assert "fungalflow/main.nf" in cmd  # checks lowercase conversion
    assert "-profile fungal_env,aws" in cmd
    assert "--sample_id 'fungal_sample_01'" in cmd

    # Verify it correctly combined the short reads into a single string
    assert "--shortreads 's3://bucket/reads_R1.fastq.gz,s3://bucket/reads_R2.fastq.gz'" in cmd

    # Verify it correctly added the longreads flag
    assert "--longreads 's3://bucket/pacbio.fastq.gz'" in cmd

    # Verify the AWS Batch work directory was set
    assert "s3://omni-compute/work/fungalflow/fungal_sample_01" in cmd