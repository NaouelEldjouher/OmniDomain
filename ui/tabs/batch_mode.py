"""
OmniDomain — Batch Mode (4+ samples)
Target user: bioinformatician, power user.
One CLI command uploads everything.
App scans S3 and auto-matches files to samples.
No manual S3 URI copying.
"""
import streamlit as st
import boto3
import pandas as pd
import io
import os
from datetime import datetime
from core.db import create_run, mark_submitted
from core.nextflow_builder import build_command
from core.tsv_validator import validate_structure, validate_s3_files

COMPUTE_BUCKET    = os.getenv("OMNI_COMPUTE_BUCKET", "omni-compute")
AWS_REGION        = os.getenv("AWS_REGION", "eu-central-1")
AWS_BATCH_JOB_DEF = os.getenv("AWS_BATCH_JOB_DEFINITION", "omni-nextflow-job")
AWS_BATCH_QUEUE   = os.getenv("AWS_BATCH_QUEUE", "omni-batch-queue")
BASE_OUTDIR       = os.getenv("OMNI_BASE_OUTDIR", "results")

# Naming convention: suffix → TSV column
CONVENTIONS = {
    "FungalFlow": [
        {"suffix": "_R1.fastq.gz",      "col": "shortreads_r1"},
        {"suffix": "_R2.fastq.gz",      "col": "shortreads_r2"},
        {"suffix": "_1.fastq.gz",       "col": "shortreads_r1"},
        {"suffix": "_2.fastq.gz",       "col": "shortreads_r2"},
        {"suffix": "_ont.fastq.gz",     "col": "longreads"},
        {"suffix": "_proteins.faa",     "col": "protein_hints"},
        {"suffix": "_proteins.faa.gz",  "col": "protein_hints"},
    ],
    "PhytoFlow": [
        {"suffix": "_hifi.fastq.gz",    "col": "hifi_reads"},
        {"suffix": "_hifi.fq.gz",       "col": "hifi_reads"},
        {"suffix": "_ref.fna",          "col": "reference"},
        {"suffix": "_ref.fna.gz",       "col": "reference"},
        {"suffix": "_ref.fasta",        "col": "reference"},
        {"suffix": "_proteins.faa",     "col": "proteins"},
        {"suffix": "_hic.bam",          "col": "hic_map"},
    ],
    "NextAMR": [
        {"suffix": "_R1.fastq.gz",      "col": "illumina_r1"},
        {"suffix": "_R2.fastq.gz",      "col": "illumina_r2"},
        {"suffix": "_1.fastq.gz",       "col": "illumina_r1"},
        {"suffix": "_2.fastq.gz",       "col": "illumina_r2"},
        {"suffix": "_ont.fastq.gz",     "col": "ont_reads"},
    ],
}

STARTER_COLS = {
    "FungalFlow": ["sample_id"],
    "PhytoFlow":  ["sample_id", "genome_type"],
    "NextAMR":    ["sample_id"],
}

COST = {
    "FungalFlow": (5, 15, "per sample ~35Mb"),
    "PhytoFlow":  (20, 50, "per sample ~120Mb"),
    "NextAMR":    (0.5, 2, "per sample ~5Mb"),
}


def render(pipeline: str):
    user_id    = st.session_state.get("user_id")
    convention = CONVENTIONS.get(pipeline, [])
    s3_prefix  = f"s3://{COMPUTE_BUCKET}/uploads/{pipeline.lower()}/"

    # ── Step 1: Naming convention ─────────────────────────────────────────────
    with st.expander("📖 Step 1 — File naming convention", expanded=False):
        st.markdown(
            f"Name files as **`{{sample_id}}{{suffix}}`**. "
            "The app will auto-match them to the correct column."
        )
        df_conv = pd.DataFrame([
            {"Suffix": c["suffix"],
             "Column": c["col"],
             "Example": f"my_sample{c['suffix']}"}
            for c in convention
        ])
        st.dataframe(df_conv, use_container_width=True)

    # ── Step 2: Upload via CLI ────────────────────────────────────────────────
    with st.expander("💻 Step 2 — Upload all files (one command)", expanded=True):
        st.markdown("Put all read files in one folder, then upload everything at once:")
        st.code(
            f"aws s3 cp ./my_reads/ \\\n"
            f"    {s3_prefix} \\\n"
            f"    --recursive \\\n"
            f"    --region {AWS_REGION}",
            language="bash"
        )
        st.caption(
            "10 files or 1000 files — same command. "
            "AWS CLI uploads in parallel. "
            "Verify with: "
            f"`aws s3 ls {s3_prefix} --recursive --human-readable`"
        )

    # ── Step 3: Starter TSV ───────────────────────────────────────────────────
    with st.expander("📋 Step 3 — Upload starter TSV (sample names only)", expanded=True):
        cols = STARTER_COLS.get(pipeline, ["sample_id"])

        # Show example
        ex = {"sample_id": ["sample_01","sample_02","sample_03","sample_04"]}
        if "genome_type" in cols:
            ex["genome_type"] = ["nuclear","nuclear","organelle","nuclear"]
        df_ex = pd.DataFrame(ex)

        col1, col2 = st.columns([2,1])
        with col1:
            st.dataframe(df_ex, use_container_width=True)
            st.caption(
                "sample_id must match the filename prefix exactly. "
                "Example: `sample_01` matches `sample_01_R1.fastq.gz`"
            )
        with col2:
            buf = io.StringIO()
            df_ex.to_csv(buf, sep="\t", index=False)
            st.download_button(
                "⬇️ Download starter TSV",
                buf.getvalue(),
                f"{pipeline.lower()}_starter.tsv",
                "text/tab-separated-values",
                use_container_width=True
            )

        uploaded = st.file_uploader(
            "Upload your completed starter TSV",
            type=["tsv","txt"],
            key=f"batch_tsv_{pipeline}"
        )
        if uploaded:
            try:
                df = pd.read_csv(uploaded, sep="\t")
                if "sample_id" not in df.columns:
                    st.error("TSV must have a sample_id column.")
                    return
                st.session_state["starter_df"] = df
                st.success(
                    f"✅ {len(df)} samples: "
                    f"{', '.join(df['sample_id'].tolist())}"
                )
            except Exception as e:
                st.error(f"Failed to read TSV: {e}")

    if "starter_df" not in st.session_state:
        st.info("Complete Steps 1–3 to continue.")
        return

    df = st.session_state["starter_df"]

    # ── Step 4: Scan S3 + auto-match ─────────────────────────────────────────
    with st.expander("🔍 Step 4 — Scan S3 and auto-match files", expanded=True):
        if st.button("🔍 Scan S3", type="primary"):
            with st.spinner("Scanning S3..."):
                file_map = _scan_s3(pipeline, df["sample_id"].tolist(), convention)
            st.session_state["file_map"] = file_map

        if "file_map" not in st.session_state:
            st.caption("Click Scan S3 after uploading files.")
            return

        file_map = st.session_state["file_map"]

        # Match table
        rows = []
        for sid in df["sample_id"]:
            for c in convention:
                uri = file_map.get(sid, {}).get(c["col"], "")
                rows.append({
                    "Sample": sid,
                    "Column": c["col"],
                    "File":   uri.split("/")[-1] if uri else "❌ not found",
                    "Status": "✅" if uri else "—"
                })
        st.dataframe(pd.DataFrame(rows), use_container_width=True)

        # Manual override for unmatched files
        unmatched = [
            (sid, c)
            for sid in df["sample_id"]
            for c in convention
            if not file_map.get(sid, {}).get(c["col"])
        ]
        if unmatched:
            with st.expander(f"⚠️ {len(unmatched)} unmatched — fix manually"):
                for sid, c in unmatched:
                    val = st.text_input(
                        f"{sid} → {c['col']}",
                        placeholder=f"s3://{COMPUTE_BUCKET}/uploads/{pipeline.lower()}/{sid}/{sid}{c['suffix']}",
                        key=f"fix_{sid}_{c['col']}"
                    )
                    if val:
                        file_map.setdefault(sid, {})[c["col"]] = val

    if "file_map" not in st.session_state:
        return

    file_map = st.session_state["file_map"]

    # ── Step 5: Build complete TSV ────────────────────────────────────────────
    st.markdown("### Step 5 — Review and launch")

    rows = []
    for _, row in df.iterrows():
        sid     = str(row["sample_id"]).strip()
        new_row = {"sample_id": sid}
        if "genome_type" in df.columns:
            new_row["genome_type"] = row.get("genome_type", "-")
        for c in convention:
            new_row[c["col"]] = file_map.get(sid, {}).get(c["col"], "-")
        rows.append(new_row)

    df_complete = pd.DataFrame(rows)
    st.dataframe(df_complete, use_container_width=True)

    # Stats
    total   = len(df) * len(convention)
    matched = sum(
        1 for sid in df["sample_id"]
        for c in convention
        if file_map.get(sid, {}).get(c["col"])
    )
    c1, c2, c3 = st.columns(3)
    c1.metric("Samples",       len(df))
    c2.metric("Files matched", matched)
    c3.metric("Files missing", total - matched)

    # Cost estimate
    mn, mx, note = COST.get(pipeline, (0, 0, ""))
    st.info(
        f"💰 **Estimated cost: ${mn*len(df)}–${mx*len(df)}** "
        f"({note} × {len(df)} samples) · AWS eu-central-1 Spot"
    )
    if mx * len(df) > 100:
        st.warning(f"⚠️ Large run — up to ${mx*len(df)}. Confirm before launching.")

    # Download complete TSV for audit
    buf = io.StringIO()
    df_complete.to_csv(buf, sep="\t", index=False)
    st.download_button(
        "⬇️ Download complete TSV (for your records)",
        buf.getvalue(),
        f"{pipeline.lower()}_complete.tsv",
        "text/tab-separated-values"
    )

    resume = st.checkbox("-resume (continue failed run from last checkpoint)")

    if matched == 0:
        st.error("No files matched. Check naming convention and S3 upload.")
        return

    if st.button("🚀 Launch All", type="primary", use_container_width=True):
        # Tier A — structural validation
        errors = validate_structure(df_complete, pipeline)
        if errors:
            for e in errors:
                st.error(f"❌ {e}")
        else:
            _launch(pipeline, df_complete, user_id, resume)


def _scan_s3(pipeline: str, sample_ids: list, convention: list) -> dict:
    """Scan S3 prefix and match files to samples by naming convention."""
    s3        = boto3.client("s3")
    prefix    = f"uploads/{pipeline.lower()}/"
    file_map  = {sid: {} for sid in sample_ids}
    all_keys  = []

    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=COMPUTE_BUCKET, Prefix=prefix):
        for obj in page.get("Contents", []):
            all_keys.append(obj["Key"])

    for key in all_keys:
        filename = key.split("/")[-1]
        for sid in sample_ids:
            for c in convention:
                if filename == f"{sid}{c['suffix']}":
                    file_map[sid][c["col"]] = f"s3://{COMPUTE_BUCKET}/{key}"

    return file_map


def _launch(pipeline: str, df: pd.DataFrame, user_id: str, resume: bool):
    """Submit one AWS Batch job per row."""
    batch     = boto3.client("batch")
    submitted, failed = [], []

    with st.spinner(f"Submitting {len(df)} job(s)..."):
        for _, row in df.iterrows():
            sample_id = str(row["sample_id"]).strip()
            tsv_row   = row.to_dict()
            cmd       = build_command(pipeline, row, resume=resume)
            job_name  = f"omni-{pipeline.lower()}-{sample_id}-{datetime.now().strftime('%H%M%S')}"

            try:
                run_id = create_run(user_id, pipeline, sample_id,
                                   tsv_row, BASE_OUTDIR)
                resp   = batch.submit_job(
                    jobName=job_name,
                    jobQueue=AWS_BATCH_QUEUE,
                    jobDefinition=AWS_BATCH_JOB_DEF,
                    containerOverrides={"command": ["bash", "-c", cmd]},
                    tags={"pipeline": pipeline, "sample_id": sample_id}
                )
                mark_submitted(run_id, resp["jobId"], job_name, resume)
                submitted.append({
                    "sample_id": sample_id,
                    "job_id":    resp["jobId"],
                    "status":    "SUBMITTED"
                })
            except Exception as e:
                failed.append({"sample_id": sample_id, "error": str(e)})

    st.session_state.setdefault("active_runs", []).extend(submitted)

    if submitted:
        st.success(f"✅ {len(submitted)} job(s) submitted")
        st.dataframe(pd.DataFrame(submitted), use_container_width=True)
        st.info("👉 Check progress in **Tab 2 — Monitor**")
    if failed:
        st.error(f"❌ {len(failed)} failed:")
        st.dataframe(pd.DataFrame(failed), use_container_width=True)