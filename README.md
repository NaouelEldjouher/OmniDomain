# OmniDomain
 
A cloud-native multi-kingdom genomics platform. Assembles, annotates,
and compares genomes for bacteria, fungi, and plants from a single unified infrastructure.
 
**Model:** Experimental BYOC (Bring Your Own Cloud)
All compute runs in your AWS account. You pay AWS directly.
OmniDomain provides the pipelines, the infrastructure code, and the UI — not the servers.
 
---
 
## Pipelines
 
| Pipeline | Kingdom | Input | Status |
|---|---|---|---|
| 🍄 FungalFlow | Fungi | Illumina / ONT / Hybrid | ✅ v1.0 validated |
| 🌱 PhytoFlow | Plants | PacBio HiFi | ✅ v1.0 validated |
| 🦠 NextAMR | Bacteria | Illumina / ONT / Hybrid | ✅ v1.0 validated |
| 🧫 MetaCflow | Metagenomes | Illumina / ONT | 🔧 Planned |
 
---
 
## FungalFlow
 
Fungal genome assembly, structural annotation, functional annotation,
secondary metabolite detection, and secretome prediction.
 
**Organisms:** Aspergillus, Trichoderma, Fusarium, Penicillium, Candida
**Input:** Illumina / ONT / Hybrid · **Genome size:** 20–80 Mb
 
| Tool | Purpose |
|---|---|
| SPAdes / Flye | Assembly (Illumina/Hybrid or ONT) |
| Funannotate / BRAKER3 | Structural annotation |
| eggNOG-mapper | GO terms, KEGG pathways, COG categories |
| dbCAN | CAZyme annotation (GH, GT, PL, CE, AA families) |
| antiSMASH 7 | BGC detection (PKS, NRPS, terpenes, RiPPs) |
| DeepSig | Secretome prediction (signal peptide detection) |


```bash
# Short reads (Illumina)
nextflow run nextflow/fungalflow/main.nf \
    -c nextflow/nextflow.config \
    -profile fungal_env \
    --shortreads 'data/aspergillus_{R1,R2}.fastq.gz' \
    --sample_id 'aspergillus_niger_case1' \
    --base_outdir 'results' \
    --eggnog_db_dir '/databases/eggnog' \
    --dbcan_db '/databases/dbcan'

# Long reads (ONT)
nextflow run nextflow/fungalflow/main.nf \
    -c nextflow/nextflow.config \
    -profile fungal_env \
    --longreads 'data/fumigatus_ont.fastq.gz' \
    --sample_id 'aspergillus_fumigatus_case2' \
    --base_outdir 'results'
# Hybrid (Illumina + ONT)
nextflow run nextflow/fungalflow/main.nf \
    -profile fungal_env \
    --shortreads 'data/niger_{R1,R2}.fastq.gz' \
    --longreads 'data/niger_ont.fastq.gz' \
    --sample_id 'aspergillus_niger_case3' \
    --base_outdir 'results'

```
**Note:** Run from the `nextflow/` directory or the config will not load.
> The pipeline auto-detects mode from inputs — no manual flags required.
 
### Validated results (v1.0)
 
| Case | Input | Assembly | Proteins | CAZymes | BGCs | Secreted |
|---|---|---|---|---|---|---|
| Case 1 — *A. niger* CBS 513.88 | Illumina | 9,958 contigs · 5.2Mb | 1,730 | 283 | 1 | 92 |
| Case 2 — *A. fumigatus* C6 | ONT | 40 contigs · N50 19.5kb | — | 11 | — | — |
| Case 3 — Hybrid | Illumina + ONT | 9,888 contigs · 5.2Mb | 1,730 | 243 | 1 | 91 |
 
---

## PhytoFlow
 
HiFi-first plant genome assembly, annotation, and comparative genomics.
Auto-detects the appropriate analysis mode from inputs — no manual tool selection required.
 
**Organisms:** Arabidopsis, wheat, barley, tomato, maize, Brassica
**Input:** PacBio HiFi · **Genome size:** 100 Mb – 16 Gb
 
| Mode | Trigger | What runs |
|---|---|---|
| Organelle | `--genome_type organelle` | Assembly + QC + Repeat masking |
| Nuclear de novo | `--genome_type nuclear` | + Helixer gene prediction + Functional annotation |
| Nuclear + reference | `--genome_type nuclear --reference ref.fna` | + RagTag scaffolding + BRAKER3 annotation |
 
---
 
## Run PhytoFlow:
 
```bash
# Organelle assembly (chloroplast / mitochondrion)
nextflow run nextflow/phytoflow/main.nf \
    -c nextflow/nextflow.config \
    -profile eukaryote_env \
    --hifi_reads 'test_data/plant_hifi_reads.fastq.gz' \
    --genome_type organelle \
    --outdir 'results/organelle'
 
# Nuclear de novo (Helixer annotation)
nextflow run nextflow/phytoflow/main.nf \
    -c nextflow/nextflow.config \
    -profile eukaryote_env \
    --hifi_reads 'test_data/arabidopsis_nuclear_hifi_5k.fastq.gz' \
    --genome_type nuclear \
    --helixer_models_dir '/path/to/helixer_models' \
    --nlr_jar 'nextflow/phytoflow/assets/nlr-annotator/NLR-Annotator-v2.1b.jar' \
    --nlr_mot 'nextflow/phytoflow/assets/nlr-annotator/mot.txt' \
    --nlr_store 'nextflow/phytoflow/assets/nlr-annotator/store.txt' \
    --outdir 'results/nuclear_denovo'
 
# Nuclear + reference (MAKER annotation)
nextflow run nextflow/phytoflow/main.nf \
    -c nextflow/nextflow.config \
    -profile eukaryote_env \
    --hifi_reads 'test_data/arabidopsis_nuclear_hifi_5k.fastq.gz' \
    --genome_type nuclear \
    --reference 'test_data/arabidopsis_reference.fna.gz' \
    --proteins 'test_data/arabidopsis_proteins.faa.gz' \
    --nlr_jar 'nextflow/phytoflow/assets/nlr-annotator/NLR-Annotator-v2.1b.jar' \
    --nlr_mot 'nextflow/phytoflow/assets/nlr-annotator/mot.txt' \
    --nlr_store 'nextflow/phytoflow/assets/nlr-annotator/store.txt' \
    --outdir 'results/nuclear_reference'
```
 
---
 
### Validated results (v1.0)
 
| Case | Mode | Assembly | Key finding |
|---|---|---|---|
| Case 1 — *Arabidopsis* organelle | Organelle | Chloroplast 155,667 bp · 0 gaps | 100.8% complete · IR coverage 340-382x |
| Case 2 — *Arabidopsis* nuclear | Nuclear de novo | 38 contigs ≥21kb | 527 proteins predicted by Helixer |
| Case 3 — *Arabidopsis* nuclear + ref | Nuclear + reference | Chr4 scaffolded | PHYA detected · 770 proteins |
 
> **Note on BUSCO for organelles:** 0% BUSCO is the correct result for
> chloroplast/mitochondrion assemblies. All 1,614 BUSCO genes are nuclear-encoded.
 
---
 
## UI — Streamlit Web Interface
 
A browser-based submission interface connecting scientists to AWS Batch
without any command-line experience required.
 
**Two submission modes:**
 
**Form mode** (1–3 samples) — upload files directly in the browser,
fill a form, click Launch. Files transfer via the Streamlit server to S3
(max 200MB per file).
 
**Batch mode** (4+ samples) — upload all files with one AWS CLI command,
upload a starter TSV with sample names, the app auto-matches files to
samples by naming convention, then submits all jobs at once.
 
```bash
# Install and run
pip install -r ui/requirements.txt
streamlit run ui/app.py
# Open http://localhost:8501
```
 
**Features:**
- Email-based login with PostgreSQL run history (SQLite for local dev)
- Cost estimates before submission
- Live AWS Batch status monitoring
- Presigned S3 download links for results
---
 
## AWS Deployment (Experimental BYOC)
 
All infrastructure is managed with Terraform. Runs on AWS Batch with
Spot instances — 60–80% cheaper than On-Demand. Nextflow `-resume`
handles Spot interruptions automatically.
 
```bash
# Deploy infrastructure
cd terraform && terraform apply
 
# Generate .env
terraform output -raw env_template > ../.env
 
# Build and push Docker image to ECR
bash bin/setup_aws_batch.sh
 
# Populate tool databases on EFS
bash bin/setup_fungalflow.sh --db-root /mnt/databases
bash bin/setup_phytoflow.sh  --db-root /mnt/databases
 
# Run UI
streamlit run ui/app.py
```
 
**Idle cost:** ~$5/month · **Per run:** $2–8 (FungalFlow) · $10–30 (PhytoFlow)
 
See [DEPLOYMENT.md](DEPLOYMENT.md) for the full step-by-step guide.
 
---
 
## Requirements
 
- Nextflow ≥ 23.04.0 (tested on 25.10.4)
- Docker or Singularity
- 20GB RAM minimum · 64GB recommended for large plant genomes
- 8 CPUs minimum
---
 
## Execution Profiles
 
| Profile | Pipeline | Usage |
|---|---|---|
| `fungal_env` | FungalFlow | `-profile fungal_env` |
| `eukaryote_env` | PhytoFlow | `-profile eukaryote_env` |
| `staphb_amr` | NextAMR | `-profile staphb_amr` |
| `local_dev` | All | `-profile fungal_env,local_dev` (20GB RAM, 8 CPUs) |
| `aws` | All | `-profile fungal_env,aws` (256GB RAM, 64 CPUs, S3 output) |
 
---
 
## Database Setup
 
```bash
# FungalFlow databases
bash bin/setup_fungalflow.sh
 
# PhytoFlow databases (Helixer + NLR-Annotator + eggNOG + BUSCO)
bash bin/setup_phytoflow.sh
```
 
NLR-Annotator assets are downloaded at runtime by the setup script —
not bundled in the repository.
 
---
 
## CI / Testing
 
| Pipeline | CI | Status |
|---|---|---|
| FungalFlow | GitHub Actions — 3 stub jobs (Illumina, ONT, Hybrid) | ✅ |
| PhytoFlow | GitHub Actions — 3 stub jobs (organelle, nuclear, nuclear+ref) | ✅ |
| UI | GitHub Actions — pytest + PostgreSQL schema | ✅ |
| Terraform | GitHub Actions — validate + fmt + Dockerfile lint | ✅ |
 
---
 
## Known Limitations (v1.0)
 
| Limitation | Planned |
|---|---|
| RepeatModeler for nuclear (EDTA better for plants) | v2.0 |
| No MultiQC aggregation report | v2.0 |
| No nf-core schema validation | v2.0 |
| MAKER not yet validated (needs RNA-seq test data) | v2.0 |
| MetaCflow placeholder only | v1.1 |
 
---
 
## Author
 
**Naouel El Djouher**
M.Sc. Agrobiotechnology (JLU Giessen) · Full-stack Bioinformatician
 
GitHub: [@NaouelEldjouher](https://github.com/NaouelEldjouher)
 
