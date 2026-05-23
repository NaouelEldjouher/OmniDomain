"""
OmniDomain — App Entry Point
streamlit run ui/app.py
"""
import sys
from pathlib import Path
ui_dir = Path(__file__).resolve().parent
if str(ui_dir) not in sys.path:
    sys.path.insert(0, str(ui_dir))

import streamlit as st
import boto3
from dotenv import load_dotenv
load_dotenv(ui_dir.parent / '.env')

st.set_page_config(
    page_title="OmniDomain",
    page_icon="🧬",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ── Login gate ────────────────────────────────────────────────────────────────
from tabs.login import render as render_login
import os
if not os.getenv("DATABASE_URL"):
    st.warning("⚠️ DATABASE_URL not set — running without user tracking")
    st.session_state.setdefault("logged_in", True)
    st.session_state.setdefault("user_id", "local")
    st.session_state.setdefault("user_name", "Local User")
    st.session_state.setdefault("user_email", "local@localhost")
elif not render_login():
    st.stop()

# ── Sidebar ───────────────────────────────────────────────────────────────────
with st.sidebar:
    st.markdown(f"👤 **{st.session_state.get('user_name','User')}**")
    st.caption(st.session_state.get('user_email',''))
    if st.button("Sign out", use_container_width=True):
        for k in ["user_id","user_email","user_name","mode",
                  "samples","file_map","starter_df","active_runs"]:
            st.session_state.pop(k, None)
        st.rerun()

    st.divider()
    st.markdown("**AWS**")
    try:
        identity = boto3.client('sts').get_caller_identity()
        st.success(f"✅ {identity['Arn'].split('/')[-1]}")
    except Exception:
        st.error("❌ No credentials")

    st.divider()
    st.markdown("**Pipeline**")
    pipeline = st.selectbox(
        "Pipeline",
        ["FungalFlow","PhytoFlow","NextAMR"],
        key="selected_pipeline",
        label_visibility="collapsed"
    )

# ── Tabs ──────────────────────────────────────────────────────────────────────
from tabs import submit, monitor, results

st.title("🧬 OmniDomain Genomics Platform")
st.caption(f"Pipeline: **{pipeline}**")

tabs = st.tabs(["1️⃣  Submit", "2️⃣  Monitor", "3️⃣  Results"])

with tabs[0]: submit.render(pipeline)
with tabs[1]: monitor.render()
with tabs[2]: results.render()
