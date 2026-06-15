"""
OmniDomain — TSV Validator
Two-tier validation: structure first, then S3 file existence.

Tier A — Structural validation (instant, no AWS calls):
  - Required columns present
  - sample_id unique
  - genome_type values valid (PhytoFlow)
  - At least one read column non-empty per row

Tier B — File integrity (async S3 checks):
  - Every file path resolves to an existing S3 object
  - File extensions match expected types
"""

import pandas as pd
from typing import List, Dict, Tuple
from ui.core.s3_client import file_exists, key_from_uri, COMPUTE_BUCKET


# ── Schema definitions per pipeline ──────────────────────────────────────────
SCHEMAS = {
    "FungalFlow": {
        "required":  ["sample_id"],
        "reads_cols": ["shortreads_r1", "shortreads_r2", "longreads"],
        "optional":  ["rnaseq_bam", "protein_hints"],
        "file_cols": ["shortreads_r1", "shortreads_r2", "longreads",
                      "rnaseq_bam", "protein_hints"],
        "read_extensions": [".fastq.gz", ".fq.gz", ".fastq", ".fq"],
    },
    "PhytoFlow": {
        "required":  ["sample_id", "genome_type"],
        "reads_cols": ["hifi_reads"],
        "optional":  ["reference", "proteins", "hic_map"],
        "file_cols": ["hifi_reads", "reference", "proteins", "hic_map"],
        "enum_cols": {"genome_type": ["organelle", "nuclear"]},
        "read_extensions": [".fastq.gz", ".fq.gz"],
    },
    "NextAMR": {
        "required":  ["sample_id"],
        "reads_cols": ["illumina_r1", "illumina_r2"],
        "optional":  ["ont_reads"],
        "file_cols": ["illumina_r1", "illumina_r2", "ont_reads"],
        "read_extensions": [".fastq.gz", ".fq.gz"],
    },
}


def validate_structure(df: pd.DataFrame, pipeline: str) -> List[str]:
    """
    Tier A: validate TSV structure without any S3 calls.
    Returns list of error strings — empty list = valid.
    """
    errors = []
    schema = SCHEMAS.get(pipeline, {})
    if not schema:
        return [f"Unknown pipeline: {pipeline}"]

    # Required columns present
    for col in schema.get("required", []):
        if col not in df.columns:
            errors.append(f"Missing required column: '{col}'")

    # sample_id uniqueness
    if "sample_id" in df.columns:
        dupes = df[df.duplicated("sample_id")]["sample_id"].tolist()
        if dupes:
            errors.append(f"Duplicate sample_id values: {dupes}")

    # Enum validation
    for col, valid_values in schema.get("enum_cols", {}).items():
        if col in df.columns:
            invalid = df[~df[col].isin(valid_values)][col].unique().tolist()
            if invalid:
                errors.append(
                    f"Column '{col}' has invalid values: {invalid}. "
                    f"Allowed: {valid_values}"
                )

    # At least one read column non-empty per row
    read_cols = [c for c in schema.get("reads_cols", []) if c in df.columns]
    if read_cols:
        for i, row in df.iterrows():
            has_reads = any(
                pd.notna(row.get(c)) and str(row.get(c, "")).strip() not in ("", "none", "nan", "-")
                for c in read_cols
            )
            if not has_reads:
                errors.append(
                    f"Row {i+1} (sample '{row.get('sample_id', '?')}') "
                    f"has no read files. At least one of {read_cols} must be set."
                )

    return errors


def validate_s3_files(df: pd.DataFrame, pipeline: str) -> List[Dict]:
    """
    Tier B: check that every file path in the TSV exists in S3.
    Returns list of error dicts with row, column, value, message.
    Runs async-style — collect all errors before returning.
    """
    errors = []
    schema = SCHEMAS.get(pipeline, {})
    file_cols = schema.get("file_cols", [])
    valid_extensions = schema.get("read_extensions", [".fastq.gz", ".fq.gz"])

    def is_set(val) -> bool:
        return pd.notna(val) and str(val).strip().lower() not in ("", "none", "nan", "-")

    def check_extension(val: str) -> bool:
        return any(str(val).endswith(ext) for ext in valid_extensions + [".fna", ".fasta", ".bam", ".faa", ".faa.gz"])

    for i, row in df.iterrows():
        sample = row.get("sample_id", f"Row {i+1}")

        for col in file_cols:
            val = row.get(col)
            if not is_set(val):
                continue

            val_str = str(val).strip()

            # Extension check
            if not check_extension(val_str):
                errors.append({
                    "row": i+1, "sample": sample, "column": col,
                    "value": val_str,
                    "message": f"Unexpected file extension. Check that '{col}' points to a valid sequencing file."
                })
                continue

            # S3 existence check
            if val_str.startswith("s3://"):
                key = key_from_uri(val_str, COMPUTE_BUCKET)
                bucket = COMPUTE_BUCKET
            else:
                key = f"uploads/{pipeline.lower()}/{sample}/{val_str}"
                bucket = COMPUTE_BUCKET

            if not file_exists(bucket, key):
                errors.append({
                    "row": i+1, "sample": sample, "column": col,
                    "value": val_str,
                    "message": f"File not found in S3: s3://{bucket}/{key}"
                })

    return errors
