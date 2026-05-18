"""
AMR-Flow: Cloud Data Integrity Validator
This module acts as a 'Pre-Flight Guardrail'. By using boto3 to verify 
S3 object existence before triggering AWS Batch, it prevents 'zombie jobs' 
and significantly reduces wasted cloud compute costs caused by missing data.
"""
import streamlit as st
import pandas as pd
import os
import boto3
import botocore
from botocore.exceptions import ClientError
# AMR-Flow: Cloud Data Integrity Validator
# Verified for HeadNode IAM Role integration
s3 = boto3.client('s3')

def check_s3_file_exists(s3_client, bucket_name, s3_key):
    """Pings S3 to check if a specific file exists."""
    try:
        s3_client.head_object(Bucket=bucket_name, Key=s3_key)
        return True
    except botocore.exceptions.ClientError as e:
       
        if e.response['Error']['Code'] == "404":
            return False
       
        return False
def render_validator():
    st.header("🛡️ 2. Cloud Data Validation")
    st.write("Verifying that your FastQ files are safely stored in S3 before launching AWS Batch.")

    if 'tsv_path' not in st.session_state:
        st.warning("⚠️ Please generate or upload a `sample.tsv` in Tab 1 first.")
        return
    compute_bucket = os.getenv("AMR_COMPUTE_BUCKET")
    static_bucket = os.getenv("AMR_STATIC_BUCKET")
    
    # Pull the TSV path from Tab 1
    tsv_path = st.session_state['tsv_path']
   
    if not compute_bucket or not static_bucket:
        st.error("🚨 Configuration Missing: Ensure `AMR_COMPUTE_BUCKET` and `AMR_STATIC_BUCKET` are set in .env")
        return
    # Load and display the TSV
    try:
        df = pd.read_csv(tsv_path, sep='\t')
        st.markdown("### Current Sample Sheet")
        st.dataframe(df, use_container_width=True)
    except Exception as e:
        st.error(f"Failed to read TSV: {e}")
        return

    st.markdown("### Run Pre-Flight Checks")
    st.write("This will verify your TSV format and ensure all listed files actually exist in your S3 bucket.")

    if st.button("🔍 Run Full Validation", type="primary"):
        with st.spinner("Validating TSV and pinging AWS S3..."):
            errors = []
            s3 = boto3.client('s3')
            
            # 1. Format Check: Are the required columns there?
            required_cols = ['sample', 'fastq_1', 'fastq_2', 'longreads']
            missing_cols = [col for col in required_cols if col not in df.columns]
            if missing_cols:
                errors.append(f"❌ Missing required columns in TSV: {', '.join(missing_cols)}")

            # 2. S3 Cross-Check: Do the files actually exist in S3?
            if not errors:
                def is_valid_file(val):
                    val_str = str(val).strip().lower()
                    return pd.notna(val) and val_str != "" and val_str != "none" and val_str != "nan"
                def get_s3_key(val):
                    val_str = str(val).strip()
                    # If it's a full s3:// URI, strip the bucket name to get the key
                    if val_str.startswith("s3://"):
                        return val_str.replace(f"s3://{compute_bucket}/", "")
                   
                    return f"uploads/{val_str}"
                for index, row in df.iterrows():
                    sample = row.get('sample', f"Row {index+1}")
                    
                    # Check Short Read 1
                    if is_valid_file(row.get('fastq_1')):
                        s3_key = get_s3_key(row['fastq_1'])
                        if not check_s3_file_exists(s3, compute_bucket, s3_key):
                            errors.append(f"❌ **{sample}**: Short read file `{row['fastq_1']}` not found in S3.")
                    
                    # Check Short Read 2
                    if is_valid_file(row.get('fastq_2')):
                        s3_key = get_s3_key(row['fastq_2'])
                        if not check_s3_file_exists(s3, compute_bucket, s3_key):
                            errors.append(f"❌ **{sample}**: Short read file `{row['fastq_2']}` not found in S3.")
                    
                    # Check Long Read
                    if is_valid_file(row.get('longreads')):
                        s3_key = get_s3_key(row['longreads'])
                        if not check_s3_file_exists(s3, compute_bucket, s3_key):
                            errors.append(f"❌ **{sample}**: Long read file `{row['longreads']}` not found in S3.")
            # 3. Final Verdict
            if errors:
                st.error("🚨 Validation Failed! Please fix the errors below before launching.")
                for err in errors:
                    st.write(err)
                # Remove validation state if it failed
                if 'validated_file' in st.session_state:
                    del st.session_state['validated_file']
            else:
                st.success("✨ All Pre-Flight Checks Passed! Your TSV is perfectly synced with S3.")
            
                st.session_state['validated_file'] = tsv_path
                st.info("👉 You can now proceed to **Tab 3. Launch Pipeline**.")