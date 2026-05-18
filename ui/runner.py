"""
AMR-Flow: Cloud Orchestrator
This module bridges the Streamlit frontend with the Nextflow backend. 
By utilizing Python's subprocess module, it asynchronously dispatches 
genomic tasks to the AWS Batch cluster via the '-profile aws' flag, 
ensuring the UI remains highly responsive during heavy compute loads.E
"""
import streamlit as st
import subprocess
import os
from dotenv import load_dotenv
from pathlib import Path
env_path = Path(__file__).resolve().parent.parent / '.env'
load_dotenv(dotenv_path=env_path)
def render_runner():
    st.header("🚀 3. Cloud Pipeline Launcher")
   
    compute_bucket = os.getenv("AMR_COMPUTE_BUCKET")
    static_bucket = os.getenv("AMR_STATIC_BUCKET")
    iam_role = os.getenv("AMR_JOB_ROLE_ARN")
    if iam_role:
        st.sidebar.success(f"✅ AWS Identity: {iam_role.split('/')[-1]}")
    else:
        st.sidebar.error("❌ AWS Identity Missing: Check .env file")
 
    
    if 'validated_file' not in st.session_state:
        st.warning("⚠️ Please validate your S3 data in Tab 2 first.")
        return

    input_tsv = st.session_state['validated_file']
    
    
    if not compute_bucket or not static_bucket:
        st.error("🚨Configuration Missing: Ensure `AMR_COMPUTE_BUCKET` and `AMR_STATIC_BUCKET` are set.")
        return
    st.markdown("### AWS Batch Configuration")
    s3_compute_base = f"s3://{compute_bucket}"
    s3_work = f"{s3_compute_base}/work"
    s3_out = f"{s3_compute_base}/results"
    
    # Define database path from STATIC bucket
    s3_static_base = f"s3://{static_bucket}"
    bakta_db_path = f"{s3_static_base}/databases/bakta_db"
    amr_db_path = f"{s3_static_base}/databases/amr_db/2026-01-21.1"
    col1, col2 = st.columns(2)
    with col1:
        st.text_input("S3 Work (Ephemeral)", s3_work, disabled=True)
    with col2:
        st.text_input("S3 Results (Output)", s3_out, disabled=True)
    use_resume = st.checkbox(
        "🔄 Resume from last successful step", 
        value=True, #
        help="If a previous run failed, this will skip already completed steps and pick up where it left off. Uncheck to start from scratch."
    )
    
    
    if st.button("🔥 Launch AWS Batch Pipeline"):
      
   
        nextflow_bin = "nextflow" 
        main_nf_path = os.path.abspath("nextflow/main.nf")
        current_env = os.environ.copy()
       
        cmd = [
            nextflow_bin, "run", main_nf_path,
            "-profile", "aws", # Triggers the Cloud Profile
            "-bucket-dir", s3_work,
            "--input", input_tsv,
            "--outdir", s3_out,
            "--bakta_db", bakta_db_path,
            "--amr_db", amr_db_path
    
           
        ]
        if use_resume:
            cmd.append("-resume")
        st.info("⚡ Dispatching tasks to AWS Batch Cluster...")
        log_placeholder = st.empty()
        
        try:
            process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,env=current_env)
            full_log = ""
            for line in process.stdout:
                full_log += line
                log_placeholder.code("\n".join(full_log.splitlines()[-15:]))
            process.wait()
            
            if process.returncode == 0:
                st.success("✅ Pipeline Finished! Check your S3 Results path.")
                if os.path.exists(input_tsv):
                    os.remove(input_tsv)
                    st.toast("Success! Input manifest cleaned up to save space.")
                
                # Optional: Clear the session state so the user has to 
                # validate a new file before running again
                if 'validated_file' in st.session_state:
                    del st.session_state['validated_file']
                # ----------------------------
                
            else:
               
                st.error("❌ Pipeline failed or was interrupted.")
                st.info("The manifest was kept. Fix the error and click 'Resume' to try again.")
      

        except Exception as e:
            st.error(f"Execution Error: {e}")



