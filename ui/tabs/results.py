"""OmniDomain — Tab 3: Results"""
import streamlit as st
import pandas as pd
import os
import boto3

RESULTS_BUCKET = os.getenv("OMNI_RESULTS_BUCKET", "omni-results")

def render():
    st.subheader("📦 Results")

    user_id = st.session_state.get("user_id")
    pipeline = st.session_state.get("selected_pipeline","FungalFlow").lower()

    # Sample selector from active runs or manual entry
    active = st.session_state.get("active_runs",[])
    done   = [j["sample_id"] for j in active if j.get("status")=="SUCCEEDED"]

    if done:
        selected = st.selectbox("Select sample", done)
    else:
        selected = st.text_input("Sample ID", placeholder="aspergillus_niger_case1")

    if not selected:
        st.info("No completed jobs yet. Check Monitor tab for status.")
        return

    if st.button("📂 Load results"):
        with st.spinner("Listing results..."):
            files = _list_results(pipeline, selected)

        if not files:
            st.warning(
                f"No results at "
                f"s3://{RESULTS_BUCKET}/results/{pipeline}/{selected}/"
            )
            return

        df = pd.DataFrame(files)
        df["phase"]    = df["key"].apply(
            lambda k: k.split("/")[4] if len(k.split("/"))>4 else "other")
        df["filename"] = df["key"].apply(lambda k: k.split("/")[-1])
        df["size_mb"]  = (df["size"]/1e6).round(2)

        st.success(f"{len(df)} result files found")

        for phase in sorted(df["phase"].unique()):
            with st.expander(f"📁 {phase}", expanded=True):
                for _, row in df[df["phase"]==phase].iterrows():
                    c1,c2,c3 = st.columns([4,1,1])
                    c1.code(row["filename"], language=None)
                    c2.caption(f"{row['size_mb']} MB")
                    with c3:
                        if st.button("⬇️", key=f"dl_{row['key']}"):
                            try:
                                url = boto3.client("s3").generate_presigned_url(
                                    "get_object",
                                    Params={"Bucket": RESULTS_BUCKET,
                                            "Key": row["key"]},
                                    ExpiresIn=3600
                                )
                                st.markdown(f"[Download link]({url})")
                            except Exception as e:
                                st.error(str(e))


def _list_results(pipeline: str, sample_id: str) -> list:
    s3        = boto3.client("s3")
    prefix    = f"results/{pipeline}/{sample_id}/"
    paginator = s3.get_paginator("list_objects_v2")
    files     = []
    for page in paginator.paginate(Bucket=RESULTS_BUCKET, Prefix=prefix):
        for obj in page.get("Contents",[]):
            files.append({"key": obj["Key"], "size": obj["Size"]})
    return files