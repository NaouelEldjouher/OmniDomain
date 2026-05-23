"""
OmniDomain — S3 Client
Handles all S3 operations: presigned URLs, existence checks, listing results.

Key design decisions:
- Never pass file bytes through Streamlit server — use presigned URLs
- Files upload via Streamlit server → boto3 → S3 (max 200MB per file)
- All paths follow: s3://{bucket}/{pipeline}/{sample_id}/{phase}/{tool}/
"""

import boto3
import botocore
import os
from typing import Optional


# ── S3 bucket names from environment ─────────────────────────────────────────
# Two buckets: compute (inputs + outputs) and reference (databases)
COMPUTE_BUCKET  = os.getenv("OMNI_COMPUTE_BUCKET", "omni-compute")
RESULTS_BUCKET  = os.getenv("OMNI_RESULTS_BUCKET", "omni-results")
UPLOAD_PREFIX   = "uploads"      # raw reads land here
RESULTS_PREFIX  = "results"      # pipeline outputs land here


def get_client():
    return boto3.client("s3")


def file_exists(bucket: str, key: str) -> bool:
    """Check if an S3 object exists — used by pre-flight validator."""
    try:
        get_client().head_object(Bucket=bucket, Key=key)
        return True
    except botocore.exceptions.ClientError as e:
        if e.response["Error"]["Code"] in ("404", "403"):
            return False
        raise


def get_upload_presigned_url(filename: str, pipeline: str, sample_id: str,
                              expiry: int = 3600) -> str:
    """
    Generate a presigned PUT URL for direct browser-to-S3 upload.
    
    Key structure: uploads/{pipeline}/{sample_id}/{filename}
    
    Browser uploads directly — Streamlit server never sees the bytes.
    This is the only way to handle 50GB+ HiFi datasets in a web app.
    """
    key = f"{UPLOAD_PREFIX}/{pipeline.lower()}/{sample_id}/{filename}"
    url = get_client().generate_presigned_url(
        "put_object",
        Params={"Bucket": COMPUTE_BUCKET, "Key": key},
        ExpiresIn=expiry,
        HttpMethod="PUT"
    )
    s3_uri = f"s3://{COMPUTE_BUCKET}/{key}"
    return url, s3_uri


def get_download_presigned_url(s3_uri: str, expiry: int = 3600) -> str:
    """Generate a presigned GET URL for result file download."""
    bucket, key = parse_s3_uri(s3_uri)
    return get_client().generate_presigned_url(
        "get_object",
        Params={"Bucket": bucket, "Key": key},
        ExpiresIn=expiry
    )


def list_results(pipeline: str, sample_id: str) -> list:
    """List all result files for a given pipeline + sample."""
    prefix = f"{RESULTS_PREFIX}/{pipeline.lower()}/{sample_id}/"
    paginator = get_client().get_paginator("list_objects_v2")
    files = []
    for page in paginator.paginate(Bucket=RESULTS_BUCKET, Prefix=prefix):
        for obj in page.get("Contents", []):
            files.append({
                "key":  obj["Key"],
                "size": obj["Size"],
                "last_modified": obj["LastModified"],
                "uri":  f"s3://{RESULTS_BUCKET}/{obj['Key']}"
            })
    return files


def parse_s3_uri(uri: str) -> tuple:
    """Parse s3://bucket/key into (bucket, key)."""
    uri = uri.replace("s3://", "")
    parts = uri.split("/", 1)
    return parts[0], parts[1] if len(parts) > 1 else ""


def key_from_uri(uri: str, bucket: str) -> str:
    """Extract S3 key from full s3:// URI given the bucket name."""
    return uri.replace(f"s3://{bucket}/", "")
