import streamlit as st
import boto3
import generator, validator, runner, reporter
from dotenv import load_dotenv  
from pathlib import Path        


base_dir = Path(__file__).resolve().parent.parent
env_path = base_dir / '.env'


st.set_page_config(page_title="AMR-Flow Cloud", layout="wide")

# Sidebar 
with st.sidebar:
    st.header("⚡ System Health")
    try:
        iam = boto3.client('sts').get_caller_identity()
        st.success(f"AWS Identity: {iam['Arn'].split('/')[-1]}")
    except:
        st.error("AWS Status: Offline")

    with st.expander("🛠️ Architectural Specs"):
        st.markdown("""
        **Data Strategy:**
        - Direct S3 Streaming (Stateless UI)
        - Multipart Upload Optimization
        
        **Compute Strategy:**
        - Nextflow Orchestration
        - AWS Batch (Spot Instances)
        - FusionFS Data Streaming
        
        **Design Patterns:**
        - Pre-flight Validation
        - Event-driven workflow ready
        """)

st.title("🧬 NextAMR Analysis Dashboard")



# Sidebar for AWS Health Check
with st.sidebar:
    st.header("AWS Status")
    try:
        iam = boto3.client('sts').get_caller_identity()
        st.success(f"User: {iam['Arn'].split('/')[-1]}")
    except:
        st.error("Offline: No AWS Credentials Found")


tabs = st.tabs([
    "1. Upload Data", 
    "2. Validate Sheet", 
    "3. Launch Pipeline", 
    "4. Monitor Logs",
    "5. Results Dashboard"
])

with tabs[0]: generator.render_generator()
with tabs[1]: validator.render_validator()
with tabs[2]: runner.render_runner()
with tabs[3]:
    st.subheader("AWS Batch Execution")
    st.link_button("Go to AWS Batch Console", "https://console.aws.amazon.com/batch/home")
    st.info("Monitor 'Job Status' to see the Fargate nodes scaling.")
with tabs[4]: reporter.render_reporter()