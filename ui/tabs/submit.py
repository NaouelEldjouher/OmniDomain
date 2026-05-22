"""
OmniDomain — Tab 1: Submit
Mode selector — routes to form_mode or batch_mode.
This is the only tab users need before a run.
"""
import streamlit as st
from tabs import form_mode, batch_mode

def render(pipeline: str):
    st.subheader(f"🚀 Submit — {pipeline}")


    if "mode" not in st.session_state:
        st.markdown("### How many samples?")
        c1, c2 = st.columns(2)
        with c1:
            st.markdown("""
            **1–3 samples**
            Upload files directly in the browser.
            No CLI. No TSV. Fill a form and click Launch.
            """)
            if st.button("Use Form Mode →", type="primary",
                         use_container_width=True):
                st.session_state["mode"] = "form"
                st.rerun()
        with c2:
            st.markdown("""
            **4+ samples**
            Upload all files with one CLI command.
            App auto-matches files to samples.
            """)
            if st.button("Use Batch Mode →", type="secondary",
                         use_container_width=True):
                st.session_state["mode"] = "batch"
                st.rerun()
        return

    # Mode chosen — show switch link
    mode = st.session_state["mode"]
    label = "Form mode (1–3 samples)" if mode == "form" else "Batch mode (4+ samples)"
    col1, col2 = st.columns([3, 1])
    col1.caption(f"Mode: **{label}**")
    if col2.button("Switch mode"):
        st.session_state.pop("mode", None)
        st.session_state.pop("samples", None)
        st.session_state.pop("file_map", None)
        st.rerun()

    st.divider()

    if mode == "form":
        form_mode.render(pipeline)
    else:
        batch_mode.render(pipeline)