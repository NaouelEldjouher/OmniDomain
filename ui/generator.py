"""
AMR-Flow: Secure Data Ingestion Module
This module handles the front-end user uploads. It utilizes Boto3's 
upload_fileobj to stream large genomic FastQ files directly to AWS S3. 
This ensures the Streamlit UI remains stateless, scalable, and memory-efficient.
"""
import streamlit as st
import pandas as pd
import boto3
import os
from boto3.s3.transfer import TransferConfig
from datetime import datetime
from dotenv import load_dotenv

# AMR-Flow: Secure Data Ingestion Module
load_dotenv()


def render_generator():
    st.header("☁️ 1.Cloud Upload")
    st.write("Upload your Sample Sheet and FastQ files. We will securely transfer them to your AWS S3 bucket for cloud processing.")

   
    compute_bucket = os.getenv("AMR_COMPUTE_BUCKET")
    static_bucket = os.getenv("AMR_STATIC_BUCKET")
    target_folder = f"uploads/{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    #If the bucket isn't configured, don't let the user proceed.
    if not compute_bucket or not static_bucket:
        st.error("🚨 **Configuration Missing:** S3 Buckets not found. Ensure `.env` contains `AMR_COMPUTE_BUCKET` and `AMR_STATIC_BUCKET`.")
        st.info("Check the README for instructions on setting up your AWS environment.")
    s3_client = boto3.client('s3')
    # The File Uploaders
    tsv_file = st.file_uploader("1. Upload Sample Sheet (.tsv)", type=["tsv", "txt"])
    fastq_files = st.file_uploader("2. Upload all FastQ files", type=['fastq', 'fastq.gz', 'fq', 'fq.gz'], accept_multiple_files=True)

    if tsv_file and fastq_files and compute_bucket:
        df = pd.read_csv(tsv_file, sep='\t')
        st.write("### 🔍 Preview of Original Sample Sheet")
        st.dataframe(df, width='stretch')

        if st.button("🚀 Upload Directly to S3 & Finalize"):
            with st.spinner("Streaming files to AWS S3... this may take a while for large datasets."):
                transfer_config = TransferConfig(
                multipart_threshold=1024 * 100, # 100MB
                max_concurrency=10,
                multipart_chunksize=1024 * 100, # 100MB
                use_threads=True
            )
                uploaded_paths = {}
                progress_bar = st.progress(0)
                total_files = len(fastq_files)
                
                # 1. Upload each FastQ file straight to S3
                for i, fq in enumerate(fastq_files):
                    # Construct the S3 Key (the path inside the bucket)
                    clean_name = fq.name.replace(" ", "_")
                    s3_key = f"{target_folder}/{clean_name}"
                    s3_uri = f"s3://{compute_bucket}/{s3_key}"
                    
                    try:
                        # Upload the file stream directly to S3
                        s3_client.upload_fileobj(fq, compute_bucket, s3_key,Config=transfer_config)
                        uploaded_paths[fq.name] = s3_uri
                        progress_bar.progress((i + 1) / total_files)
                    except Exception as e:
                        st.error(f"Failed to upload {fq.name}: {e}")
                        return

                # 2. Update the TSV DataFrame with the new S3 URIs
                clean_uploaded_paths = {os.path.basename(k): v for k, v in uploaded_paths.items()}
                path_cols = ['fastq_1', 'fastq_2', 'longreads']
                for col in path_cols:
                    if col in df.columns:
                        def translate_to_s3(val):
                            str_val = str(val).strip()
                            if str_val.lower() in ['none', 'nan', ''] or pd.isna(val):
                                return 'none'
                            filename = os.path.basename(str_val)
                            return clean_uploaded_paths.get(filename, val)

                        df[col] = df[col].apply(translate_to_s3)

                # 3. SAVE THE FILE
                final_tsv_path = os.path.join(os.getcwd(), "samples_cloud_ready.tsv")
                df.to_csv(final_tsv_path, sep='\t', index=False)
                
                # 4. UPDATE SESSION STATE
                st.session_state['tsv_path'] = final_tsv_path
            
                
                st.success(f"✅ Success! {len(fastq_files)} files pushed to S3.")
                st.write("### 💎 Cloud-Ready Manifest Preview")
                st.dataframe(df, use_container_width=True)
                st.info("➡️ Proceed directly to **Tab 2: Validation**.")