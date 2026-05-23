"""
OmniDomain — Form Mode (1-3 samples)
Target user: wet lab scientist, no CLI experience.
Files upload directly from browser to S3 via boto3.
No TSV, no CLI, no S3 URI copying.
"""
import streamlit as st
import boto3
import os
import pandas as pd
from core.db import create_run, mark_submitted, record_upload
from core.nextflow_builder import build_command
from core.s3_client import file_exists, COMPUTE_BUCKET

AWS_BATCH_JOB_DEF = os.getenv("AWS_BATCH_JOB_DEFINITION", "omni-nextflow-job")
AWS_BATCH_QUEUE   = os.getenv("AWS_BATCH_QUEUE", "omni-batch-queue")
BASE_OUTDIR       = os.getenv("OMNI_BASE_OUTDIR", "results")

# ── Cost table ────────────────────────────────────────────────────────────────
COST = {
    "FungalFlow": {"Illumina": (5,15,"~35Mb"), "ONT": (8,20,"Flye"), "Hybrid": (10,25,"best quality")},
    "PhytoFlow":  {"organelle": (2,5,"~160kb"), "nuclear_small": (20,50,"~120Mb"), "nuclear_large": (80,200,"~900Mb")},
    "NextAMR":    {"Illumina": (0.5,2,"~5Mb"), "Hybrid": (1,4,"Illumina+ONT")},
}

# ── Fields per pipeline ───────────────────────────────────────────────────────
FIELDS = {
    "FungalFlow": {
        "Illumina": [
            {"key": "shortreads_r1", "label": "R1 reads (.fastq.gz)", "required": True},
            {"key": "shortreads_r2", "label": "R2 reads (.fastq.gz)", "required": False},
            {"key": "protein_hints", "label": "Protein hints (.faa)", "required": False},
        ],
        "ONT": [
            {"key": "longreads",     "label": "ONT reads (.fastq.gz)", "required": True},
            {"key": "protein_hints", "label": "Protein hints (.faa)",  "required": False},
        ],
        "Hybrid": [
            {"key": "shortreads_r1", "label": "R1 reads (.fastq.gz)", "required": True},
            {"key": "shortreads_r2", "label": "R2 reads (.fastq.gz)", "required": False},
            {"key": "longreads",     "label": "ONT reads (.fastq.gz)", "required": True},
        ],
    },
    "PhytoFlow": {
        "organelle":     [{"key": "hifi_reads", "label": "HiFi reads (.fastq.gz)", "required": True}],
        "nuclear_small": [
            {"key": "hifi_reads", "label": "HiFi reads (.fastq.gz)",   "required": True},
            {"key": "reference",  "label": "Reference genome (.fna)",   "required": False},
            {"key": "proteins",   "label": "Protein hints (.faa)",      "required": False},
        ],
        "nuclear_large": [
            {"key": "hifi_reads", "label": "HiFi reads (.fastq.gz)",   "required": True},
            {"key": "reference",  "label": "Reference genome (.fna)",   "required": False},
        ],
    },
    "NextAMR": {
        "Illumina": [
            {"key": "illumina_r1", "label": "R1 reads (.fastq.gz)", "required": True},
            {"key": "illumina_r2", "label": "R2 reads (.fastq.gz)", "required": True},
        ],
        "Hybrid": [
            {"key": "illumina_r1", "label": "R1 reads (.fastq.gz)",  "required": True},
            {"key": "illumina_r2", "label": "R2 reads (.fastq.gz)",  "required": True},
            {"key": "ont_reads",   "label": "ONT reads (.fastq.gz)", "required": False},
        ],
    },
}


def render(pipeline: str):
    user_id  = st.session_state.get("user_id")
    samples  = st.session_state.setdefault("samples", [{}])

    # ── Sample forms ──────────────────────────────────────────────────────────
    for i, sample in enumerate(samples):
        with st.expander(
            f"🧬 Sample {i+1}" + (f" — {sample.get('sample_id','')}" if sample.get('sample_id') else ""),
            expanded=True
        ):
            _render_sample_form(pipeline, i, sample, user_id)

        if len(samples) > 1:
            if st.button(f"✖ Remove sample {i+1}", key=f"rm_{i}"):
                samples.pop(i)
                st.rerun()

    # ── Add sample ────────────────────────────────────────────────────────────
    if len(samples) < 3:
        if st.button("➕ Add another sample", type="secondary"):
            samples.append({})
            st.rerun()
    else:
        st.info("Maximum 3 samples in form mode. Switch to **Batch mode** for more.")

    st.divider()

    # ── Cost estimate ─────────────────────────────────────────────────────────
    _show_cost(pipeline, samples)

    st.divider()

    # ── Launch ────────────────────────────────────────────────────────────────
    resume  = st.checkbox("-resume (continue failed run from last checkpoint)")
    ready   = _all_ready(samples)

    if not ready:
        st.warning("Fill all required fields and upload all required files before launching.")

    if st.button("🚀 Launch Pipeline", type="primary",
                 use_container_width=True, disabled=not ready):
        _launch(pipeline, samples, user_id, resume)


def _render_sample_form(pipeline, idx, sample, user_id):
    """Render one sample's form fields."""
    # Sample name
    sample["sample_id"] = st.text_input(
        "Sample name",
        value=sample.get("sample_id", ""),
        placeholder="e.g. aspergillus_niger_01",
        key=f"sid_{idx}"
    )

    # Read type / genome type selector
    if pipeline == "FungalFlow":
        sample["read_type"] = st.radio(
            "Read type",
            ["Illumina", "ONT", "Hybrid"],
            key=f"rt_{idx}",
            horizontal=True
        )
        subtype = sample["read_type"]

    elif pipeline == "PhytoFlow":
        genome_type = st.radio(
            "Genome type",
            ["organelle", "nuclear"],
            key=f"gt_{idx}",
            horizontal=True
        )
        if genome_type == "nuclear":
            size = st.radio(
                "Approximate genome size",
                ["Small (<500Mb)", "Large (>500Mb)"],
                key=f"gs_{idx}",
                horizontal=True
            )
            subtype = "nuclear_small" if size.startswith("Small") else "nuclear_large"
        else:
            subtype = "organelle"
        sample["genome_type"] = genome_type
        sample["read_type"]   = subtype

    elif pipeline == "NextAMR":
        sample["read_type"] = st.radio(
            "Read type",
            ["Illumina", "Hybrid"],
            key=f"rt_{idx}",
            horizontal=True
        )
        subtype = sample["read_type"]

    # File upload fields for this mode
    if not sample.get("sample_id"):
        st.warning("Enter a sample name first.")
        return

    fields = FIELDS.get(pipeline, {}).get(subtype, [])
    sample.setdefault("files", {})

    for field in fields:
        key      = field["key"]
        label    = field["label"]
        required = field["required"]
        badge    = "required" if required else "optional"

        current_uri = sample["files"].get(key)
        if current_uri:
            st.success(f"✅ {label}")
            st.caption(current_uri)
            if st.button(f"Remove", key=f"rm_file_{idx}_{key}"):
                del sample["files"][key]
                st.rerun()
            continue

        st.markdown(f"**{label}** _{badge}_")
        uploaded = st.file_uploader(
            f"Select {label}",
            key=f"fu_{idx}_{key}",
            label_visibility="collapsed"
        )

        if uploaded:
            size_mb = len(uploaded.getvalue()) / 1e6
            st.caption(f"{uploaded.name} — {size_mb:.1f} MB")

            if size_mb > 200:
                st.error(
                    f"File is {size_mb:.0f}MB — too large for browser upload. "
                    "Switch to **Batch mode** for files >200MB."
                )
                continue

            if st.button(f"⬆️ Upload {uploaded.name}",
                         key=f"upload_{idx}_{key}", type="primary"):
                s3_key = (f"uploads/{st.session_state.get('selected_pipeline','').lower()}/"
                          f"{sample['sample_id']}/{uploaded.name}")
                s3_uri = f"s3://{COMPUTE_BUCKET}/{s3_key}"
                with st.spinner(f"Uploading {uploaded.name}..."):
                    try:
                        boto3.client("s3").upload_fileobj(
                            uploaded, COMPUTE_BUCKET, s3_key,
                            ExtraArgs={"ContentType": "application/octet-stream"}
                        )
                        sample["files"][key] = s3_uri
                        st.success(f"✅ Uploaded")
                        st.rerun()
                    except Exception as e:
                        st.error(f"Upload failed: {e}")


def _show_cost(pipeline, samples):
    """Show cost estimate based on current sample configuration."""
    if not samples or not samples[0].get("read_type"):
        return

    st.markdown("#### 💰 Estimated cost")
    total_min, total_max = 0, 0

    for i, s in enumerate(samples):
        rt = s.get("read_type", "")
        est = COST.get(pipeline, {}).get(rt, {})
        if est:
            mn, mx, note = est
            total_min += mn
            total_max += mx
            st.caption(f"Sample {i+1}: ${mn}–${mx} ({note})")

    if total_min:
        st.info(f"**Total: ${total_min}–${total_max}** · AWS eu-central-1 Spot · estimated")
        if total_max > 100:
            st.warning(f"⚠️ Large run — up to ${total_max}. Confirm before launching.")


def _all_ready(samples) -> bool:
    """Check all required fields and files are present."""
    for s in samples:
        if not s.get("sample_id"):
            return False
        if not s.get("read_type"):
            return False
        pipeline = st.session_state.get("selected_pipeline", "")
        fields   = FIELDS.get(pipeline, {}).get(s.get("read_type", ""), [])
        for f in fields:
            if f["required"] and f["key"] not in s.get("files", {}):
                return False
    return True


def _launch(pipeline, samples, user_id, resume):
    """Submit one AWS Batch job per sample."""
    from datetime import datetime
    batch      = boto3.client("batch")
    submitted  = []
    failed     = []

    with st.spinner(f"Submitting {len(samples)} job(s)..."):
        for s in samples:
            sample_id = s["sample_id"]
            tsv_row   = {
                "sample_id":   sample_id,
                "genome_type": s.get("genome_type", "-"),
                **{k: v for k, v in s.get("files", {}).items()}
            }
            # Fill missing optional cols with "-"
            fields = FIELDS.get(pipeline, {}).get(s.get("read_type",""), [])
            for f in fields:
                if f["key"] not in tsv_row:
                    tsv_row[f["key"]] = "-"

            import pandas as pd
            row_series = pd.Series(tsv_row)
            cmd        = build_command(pipeline, row_series, resume=resume)
            job_name   = (f"omni-{pipeline.lower()}-{sample_id}-"
                         f"{datetime.now().strftime('%H%M%S')}")

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