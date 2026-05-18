import streamlit as st
import pandas as pd
import boto3
import os
import glob
import json
import io
# Initialize S3 Client
compute_bucket = os.getenv("AMR_COMPUTE_BUCKET")
s3 = boto3.client('s3')

@st.cache_data(ttl=300) 
def get_s3_data_cached(bucket, key):
    """Fetch file content once and store it in memory"""
    try:
        obj = s3.get_object(Bucket=bucket, Key=key)
        return obj['Body'].read().decode('utf-8')
    except Exception:
        return None

def list_s3_files(bucket, prefix=""): 
    """Consolidated helper to list objects in S3 - prefix is now optional"""
    try:
        response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
        return [obj['Key'] for obj in response.get('Contents', [])]
    except Exception as e:
        print(f"S3 Error: {e}")
        return []
  
def render_reporter():
    st.header("📊 NextAMR Analysis Dashboard") 
    col_title, col_btn = st.columns([3, 1])
    with col_btn:

        if st.button("🔄 Extract Latest S3 Results", use_container_width=True):
            st.cache_data.clear() # Clears memory to force a fresh S3 pull
            st.rerun()
    if not compute_bucket:
        st.error("🚨 **Configuration Missing:** `AMR_COMPUTE_BUCKET` is not set.")
        st.info("Please set your compute bucket name in the .env file to view results.")
        return
  
    res_prefix = "results/"
    # --- SECTION 1: RAW READ QUALITY (FASTP) ---
    st.subheader("🧬 1. Raw Read Metrics")
    fastp_keys = [k for k in list_s3_files(compute_bucket, f"{res_prefix}fastp/") if k.endswith(".json")]
    if fastp_keys:
        qc_stats = []
        for f in fastp_keys:
            content = get_s3_data_cached(compute_bucket, f)
            if content:
                try:
                    s_name = f.split('/')[-1].split('.')[0]
                    data = json.loads(content).get('summary', {}).get('after_filtering', {})
                    total_bases = data.get('total_bases', data.get('total_bp', 0))
                    qc_stats.append({
                        "Sample": s_name,
                        "Avg Read Len": f"{int(data.get('read1_mean_length', 0))} bp",
                        "Raw GC %": round(data.get('gc_content', 0) * 100, 2),
                        "Yield (Mb)": round(total_bases / 1e6, 2),
                        "Q30 %": round(data.get('q30_rate', 0) * 100, 2)
                })
                except Exception: continue
        st.dataframe(pd.DataFrame(qc_stats), use_container_width=True)
    else:
        st.info("Waiting for Fastp results...")

    # --- SECTION 2: ASSEMBLY QUALITY (DIRECT FASTA SCAN) ---

    st.divider()
    st.subheader("🏗️ 2. Assembly Quality (N50 & GC)")
    
    all_files = list_s3_files(compute_bucket, res_prefix)
    fasta_keys = [k for k in all_files if k.endswith((".fna", ".fasta"))]

    if fasta_keys:
        fasta_stats = []
        targets = [k for k in fasta_keys if any(x in k.lower() for x in ["polished", "assembly", "flye", "unicycler"])]
        if targets:
            with st.spinner("Analyzing Cloud Assemblies..."):
                for key in targets:
                    fname = os.path.basename(key)
                    try:
                        content = get_s3_data_cached(compute_bucket, key)
                        sections = content.split('>')
                        lengths = []
                        total_g, total_c, total_n, total_len = 0, 0, 0, 0
                        
                        for s in sections[1:]:
                            lines = s.split('\n')
                            seq = "".join(lines[1:]).strip()
                            l = len(seq)
                            if l == 0: continue
                            lengths.append(l)
                            total_len += l
                            seq_upper = seq.upper()
                            total_g += seq_upper.count('G')
                            total_c += seq_upper.count('C')
                            total_n += seq_upper.count('N')
                        
                        if lengths:
                            lengths.sort(reverse=True)
                            run_sum, n50, l50 = 0, 0, 0
                            for i, l in enumerate(lengths):
                                run_sum += l
                                if run_sum >= total_len / 2:
                                    n50 = l
                                    l50 = i + 1
                                    break
                            
                            known_bases = total_len - total_n
                            gc_percent = round((total_g + total_c) / known_bases * 100, 2) if known_bases > 0 else 0
                            fasta_stats.append({
                                "Assembly File": fname,
                                "N50": f"{n50:,}",
                                "L50 (Contigs)": l50,
                                "GC %": gc_percent,
                                "Gaps (N)": f"{total_n:,}",
                                "Contigs": len(lengths)
                            })
                    except Exception as e:
                        st.error(f"Error parsing {fname}: {e}")
        
        if fasta_stats:
            st.dataframe(pd.DataFrame(fasta_stats), use_container_width=True)

    else:
        st.warning("No assembly files (.fasta/.fna) detected yet.")

    # --- SECTION 3: CLINICAL AMR REPORT ---
    st.divider()
    st.subheader("💊 3. Clinical AMR Findings & Full Report")
    
    # Fetch files 
    amr_keys = [k for k in list_s3_files(compute_bucket, f"{res_prefix}amrfinderplus/") if k.endswith(".tsv")]
    
    if amr_keys:
        all_amr = []

        # Professional Clinical Risk Heuristics
        def classify_clinical_risk(gene_symbol):
            if pd.isna(gene_symbol) or str(gene_symbol).strip() in ["-", ""]:
                return "🟢 CLEAN"
            gene = str(gene_symbol).lower()
            # Priority Pathogen Flagging (WHO/CDC criteria)
            if any(x in gene for x in ["bla", "ndm", "kpc", "oxa", "ctx", "shv", "tem"]):
                return "🚨 CRITICAL: Beta-lactamase"
            if any(x in gene for x in ["meca", "mcr", "vana", "vanb"]):
                return "⚠️ HIGH RISK"
            return "🧬 RESISTANT"

        for key in amr_keys:
            sample = os.path.basename(key).replace("_amr.tsv", "").replace(".tsv", "")
            try:
                # Utilizing the cached data helper
                content = get_s3_data_cached(compute_bucket, key)
                
                if content:
                    df = pd.read_csv(io.StringIO(content), sep='\t')
                    
                    if not df.empty:
                      
                        df.insert(0, "Sample", sample)
                        gene_col = 'Gene symbol' if 'Gene symbol' in df.columns else (df.columns[1] if len(df.columns) > 1 else None)
                        
                        if gene_col:
                            df.insert(1, "Status", df[gene_col].apply(classify_clinical_risk))
                        else:
                            df.insert(1, "Status", "UNKNOWN")
                            
                        all_amr.append(df)
                    else:
                        # Clean Sample visualization
                        all_amr.append(pd.DataFrame({
                            "Sample": [sample], 
                            "Status": ["🟢 CLEAN"], 
                            "Gene symbol": ["-"], 
                            "Class": ["No resistance genes detected"]
                        }))
            except Exception as e:
                st.error(f"Error reading AMR results for {sample}: {e}")
                continue        
        
        if all_amr:
            master_amr = pd.concat(all_amr, ignore_index=True, sort=False)
            
            # Column mapping 
            cols_map = {
                "Sample": "Sample", 
                "Status": "Clinical Status", 
                "Gene symbol": "Gene", 
                "Class": "Antibiotic Class", 
                "% Identity": "Identity %"
            }
            
            avail = [c for c in cols_map.keys() if c in master_amr.columns]
            final_df = master_amr[avail].rename(columns=cols_map)

          
            def style_status(val):
                if "CRITICAL" in str(val): return 'background-color: #ff4b4b; color: white; font-weight: bold'
                if "HIGH RISK" in str(val): return 'background-color: #ffa500; color: black; font-weight: bold'
                if "CLEAN" in str(val): return 'color: #00ff00; font-weight: bold'
                return 'color: #31333F' # Default Streamlit text color

            st.dataframe(
                final_df.style.map(style_status, subset=['Clinical Status']), 
                use_container_width=True
            )
            
            # Actionable Tools
          
        search = st.text_input("🔍 Search Clinical Insights (e.g. beta-lactam, MCR1, tet-a)")

        if search:
            # 1. Clean the search term: lowercase and remove special chars (spaces, dashes, etc.)
            clean_search = "".join(filter(str.isalnum, search)).lower()
            
            # 2. Define a helper to check if a row contains the "cleaned" search term
            def fuzzy_search(row):
            
                combined_row_text = "".join(map(str, row)).lower()
                clean_row_text = "".join(filter(str.isalnum, combined_row_text))
                
                return clean_search in clean_row_text
            # 3. Apply the filter
            query = master_amr[master_amr.apply(fuzzy_search, axis=1)]
            
            if not query.empty:
                st.write(f"Results for '{search}':")
                st.dataframe(query, use_container_width=True)
            else:
                st.warning(f"No matches found for '{search}'.")
        

        btn_col1, btn_col2, btn_col3 = st.columns([1.5, 1.2, 4]) 
        
        with btn_col1:
            # Download Button
            st.download_button(
                label="📥 Export CSV Report", 
                data=master_amr.to_csv(index=False), 
                file_name="AMR_Full_Report.csv",
                use_container_width=True
            )
        
        with btn_col2:
            # Refresh Button
            if st.button("🔄 Refresh Data", use_container_width=True):
                st.rerun()