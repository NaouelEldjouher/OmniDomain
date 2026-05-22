"""
OmniDomain — Nextflow Command Builder
Translates a validated TSV row into a Nextflow run command.

The TSV is the configuration — users never set pipeline flags manually.
genome_type, read types, optional files — all come from the TSV columns.
"""

import os
import pandas as pd
from typing import Dict, Optional


# ── Environment ───────────────────────────────────────────────────────────────
BASE_OUTDIR    = os.getenv("OMNI_BASE_OUTDIR", "s3://omni-results")
NEXTFLOW_TOWER = os.getenv("NEXTFLOW_TOWER_TOKEN", None)
AWS_QUEUE      = os.getenv("AWS_BATCH_QUEUE", "omni-batch-queue")
AWS_REGION     = os.getenv("AWS_REGION", "eu-central-1")
REPO_PATH      = os.getenv("OMNI_REPO_PATH", "nextflow")


def build_command(pipeline: str, row: pd.Series, resume: bool = False) -> str:
    """
    Build the complete nextflow run command for one TSV row.
    
    Args:
        pipeline: "FungalFlow" | "PhytoFlow" | "NextAMR"
        row: one row from the validated TSV
        resume: whether to add -resume flag
    
    Returns:
        Complete nextflow CLI command string
    """
    sample_id = str(row["sample_id"]).strip()
    pipeline_key = pipeline.lower().replace("flow", "flow")

    # Base command
    cmd = [
        "nextflow run",
        f"{REPO_PATH}/{pipeline_key}/main.nf",
        f"-c {REPO_PATH}/nextflow.config",
        f"-profile {_get_profile(pipeline)},aws",
        f"--sample_id '{sample_id}'",
        f"--base_outdir '{BASE_OUTDIR}'",
    ]

    # Pipeline-specific flags from TSV columns
    if pipeline == "FungalFlow":
        cmd.extend(_build_fungalflow_args(row))
    elif pipeline == "PhytoFlow":
        cmd.extend(_build_phytoflow_args(row))
    elif pipeline == "NextAMR":
        cmd.extend(_build_nextamr_args(row))

    # Database paths — from environment (set in AWS profile)
    cmd.extend(_build_db_args(pipeline))

    # Resume flag
    if resume:
        cmd.append("-resume")

    # AWS Batch config
    cmd.extend([
        f"-work-dir 's3://omni-compute/work/{pipeline_key}/{sample_id}'",
        f"--aws-batch-job-queue '{AWS_QUEUE}'",
    ])

    return " \\\n    ".join(cmd)


def _get_profile(pipeline: str) -> str:
    profiles = {
        "FungalFlow": "fungal_env",
        "PhytoFlow":  "eukaryote_env",
        "NextAMR":    "staphb_amr",
    }
    return profiles.get(pipeline, "docker")


def _is_set(val) -> bool:
    return pd.notna(val) and str(val).strip().lower() not in ("", "none", "nan", "-")


def _build_fungalflow_args(row: pd.Series) -> list:
    args = []
    if _is_set(row.get("shortreads_r1")):
        r1 = row["shortreads_r1"]
        r2 = row.get("shortreads_r2", "")
        if _is_set(r2):
            args.append(f"--shortreads '{r1},{r2}'")
        else:
            args.append(f"--shortreads '{r1}'")
    if _is_set(row.get("longreads")):
        args.append(f"--longreads '{row['longreads']}'")
    if _is_set(row.get("rnaseq_bam")):
        args.append(f"--rnaseq_bam '{row['rnaseq_bam']}'")
    if _is_set(row.get("protein_hints")):
        args.append(f"--protein_hints '{row['protein_hints']}'")
    return args


def _build_phytoflow_args(row: pd.Series) -> list:
    args = []
    if _is_set(row.get("hifi_reads")):
        args.append(f"--hifi_reads '{row['hifi_reads']}'")
    if _is_set(row.get("genome_type")):
        args.append(f"--genome_type '{row['genome_type']}'")
    if _is_set(row.get("reference")):
        args.append(f"--reference '{row['reference']}'")
    if _is_set(row.get("proteins")):
        args.append(f"--proteins '{row['proteins']}'")
    if _is_set(row.get("hic_map")):
        args.append(f"--hic_map '{row['hic_map']}'")
    return args


def _build_nextamr_args(row: pd.Series) -> list:
    args = []
    if _is_set(row.get("illumina_r1")):
        args.append(f"--illumina_r1 '{row['illumina_r1']}'")
    if _is_set(row.get("illumina_r2")):
        args.append(f"--illumina_r2 '{row['illumina_r2']}'")
    if _is_set(row.get("ont_reads")):
        args.append(f"--ont_reads '{row['ont_reads']}'")
    return args


def _build_db_args(pipeline: str) -> list:
    """Add database paths from environment — set in AWS profile."""
    args = []
    if pipeline in ("FungalFlow", "PhytoFlow"):
        eggnog = os.getenv("OMNI_EGGNOG_DB")
        if eggnog:
            args.append(f"--eggnog_db_dir '{eggnog}'")
    if pipeline == "FungalFlow":
        dbcan = os.getenv("OMNI_DBCAN_DB")
        if dbcan:
            args.append(f"--dbcan_db '{dbcan}'")
        funannotate = os.getenv("OMNI_FUNANNOTATE_DB")
        if funannotate:
            args.append(f"--funannotate_db '{funannotate}'")
    if pipeline == "PhytoFlow":
        helixer = os.getenv("OMNI_HELIXER_MODEL")
        if helixer:
            args.append(f"--helixer_model '{helixer}'")
    return args
