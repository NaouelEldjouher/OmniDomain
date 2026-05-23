"""OmniDomain — Tab 2: Monitor"""
import streamlit as st
import boto3
import pandas as pd
from datetime import datetime
from core.db import get_user_runs, update_status
 
ICON = {"SUBMITTED":"🟡","PENDING":"🟡","RUNNABLE":"🟠",
        "STARTING":"🔵","RUNNING":"🔵","SUCCEEDED":"🟢","FAILED":"🔴"}
 
def render():
    st.subheader("📊 Monitor")
    user_id = st.session_state.get("user_id")
 
    col1, col2 = st.columns([3,1])
    with col2:
        if st.button("🔄 Refresh", use_container_width=True):
            _refresh(st.session_state.get("active_runs",[]))
            st.rerun()
    with col1:
        st.caption(f"Last refreshed: {datetime.now().strftime('%H:%M:%S')}")
 
    # Active jobs from session
    active = st.session_state.get("active_runs", [])
    if active:
        st.markdown("#### Active jobs")
        rows = [{"Sample": j["sample_id"],
                 "Status": f"{ICON.get(j.get('status',''),'⚪')} {j.get('status','')}",
                 "Job ID": j["job_id"]} for j in active]
        st.dataframe(pd.DataFrame(rows), use_container_width=True)
 
        statuses = [j.get("status","") for j in active]
        c1,c2,c3,c4 = st.columns(4)
        c1.metric("Running",   sum(1 for s in statuses if s=="RUNNING"))
        c2.metric("Succeeded", sum(1 for s in statuses if s=="SUCCEEDED"))
        c3.metric("Failed",    sum(1 for s in statuses if s=="FAILED"))
        c4.metric("Pending",   sum(1 for s in statuses if s in ("SUBMITTED","PENDING","RUNNABLE")))
 
    # Run history from PostgreSQL
    if user_id:
        st.markdown("#### Run history")
        try:
            runs = get_user_runs(user_id)
            if runs:
                df = pd.DataFrame(runs)[
                    ["pipeline","sample_id","status",
                     "submitted_at","completed_at","cost_estimate"]
                ]
                st.dataframe(df, use_container_width=True)
            else:
                st.info("No runs yet.")
        except Exception as e:
            st.warning(f"Could not load history: {e}")
 
    st.link_button("🔗 AWS Batch Console",
                   "https://console.aws.amazon.com/batch/home")
 
 
def _refresh(jobs: list):
    if not jobs:
        return
    try:
        batch    = boto3.client("batch")
        ids      = [j["job_id"] for j in jobs]
        resp     = batch.describe_jobs(jobs=ids)
        sm       = {j["jobId"]: j["status"] for j in resp["jobs"]}
        for job in jobs:
            new_status = sm.get(job["job_id"])
            if new_status and new_status != job.get("status"):
                job["status"] = new_status
                if job.get("run_id"):
                    try:
                        update_status(job["run_id"], new_status)
                    except Exception:
                        pass
    except Exception as e:
        st.error(f"Refresh failed: {e}")