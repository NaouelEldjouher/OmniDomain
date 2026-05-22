# OmniDomain
 A cloud-native multi-kingdom genomics platform. Assembles, annotates,
and compares genomes for bacteria, fungi, and plants from a single unified infrastructure.
* **Model:** Bring Your Own Cloud (BYOC)
All compute runs in your AWS account. You pay AWS directly.
OmniDomain provides the pipelines, not the servers.
**HiFi-first plant genome assembly, annotation & comparative genomics**
 ---
 
## Pipelines
* **🍄 FungalFlow:** Fungal Genome Assembly & Functional Annotation
* **Organisms:** Aspergillus, Trichoderma, Fusarium, Penicillium, Candida
* **Input:** Illumina / ONT / Hybrid
* **Genome size:** 20–80 Mb
### Analysis
* **Assembly:** SPAdes (Illumina/Hybrid) or Flye (ONT)
* **Structural annotation:**  Funannotate / Augustus
* **Functional annotation:** eggNOG-mapper (GO, KEGG, COG)
* **CAZyme annotation:** dbCAN (GH, GT, PL, CE, AA families)
* **BGC detection:** antiSMASH 7 (PKS, NRPS, terpenes, RiPPs)
* **Secretome prediction:** DeepSig (signal peptide detection)


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
```

🌱 PhytoFlow — Plant Genome Assembly & Annotation
PhytoFlow is a Nextflow DSL2 pipeline for assembling and annotating plant genomes from PacBio HiFi reads. It auto-detects the appropriate analysis mode from your inputs — no manual tool selection required.

* **Organisms:** Arabidopsis, wheat, barley, tomato, maize, Brassica
* **Input:** PacBio HiFi
* **Genome size:** 100 Mb – 16 Gb
###Analysis:

* **Assembly:** Hifiasm (HiFi-optimised)
* **Scaffolding:** YAHS (Hi-C) or RagTag (reference-guided)
* **Structural annotation:** Helixer (deep learning) or BRAKER3 ETP
* **NBS-LRR resistance genes:** NLR-Annotator v2
* **Functional annotation:** eggNOG-mapper


 
| Mode | Trigger | What runs |
|---|---|---|
| **Organelle** | `--genome_type organelle` | Assembly + QC + Repeat masking |
| **Nuclear de novo** | `--genome_type nuclear` | + Helixer gene prediction + Functional annotation |
| **Nuclear + reference** | `--genome_type nuclear --reference ref.fna` | + RagTag scaffolding + MAKER annotation |
 
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
 
## Requirements
 
- [Nextflow](https://nextflow.io) >= 23.04.0
- [Docker](https://docker.com) or [Singularity](https://sylabs.io)
- 20GB RAM minimum (64GB recommended for large plant genomes)
- 8 CPUs minimum
---
 
## Pipeline Steps
 
### Phase 1 — QC
| Tool | Purpose |
|---|---|
| HiFiAdapterFilt | Removes PacBio SMRTbell adapter contamination |
| seqkit stats | Read N50, total bases, read count |
 
> **Note:** Filtlong is NOT used — it misinterprets HiFi CCS quality scores.
 
### Phase 2 — Assembly
| Tool | Purpose |
|---|---|
| Hifiasm | HiFi genome assembler — supports Hi-C phasing |
| GFA→FASTA | Converts assembly graph to sequence format |
 
### Phase 3 — Assembly QC
| Tool | Purpose |
|---|---|
| QUAST | Assembly statistics (N50, L50, contig count, gaps) |
| BUSCO | Gene space completeness (embryophyta_odb10) |
| minimap2 + samtools | Read coverage validation per contig |
 
> **Note on BUSCO for organelles:** 0% BUSCO is the correct result for chloroplast/mitochondrion assemblies. All 1,614 BUSCO genes are nuclear-encoded.
 
### Phase 4 — Scaffolding *(nuclear mode only)*
| Tool | Trigger | Purpose |
|---|---|---|
| YAHS | `--hic_map` provided | Hi-C contact map → chromosome-level scaffolding |
| RagTag | `--reference` provided | Reference-guided scaffolding |
 
> **Note:** Never provide a nuclear reference for organelle assemblies — organelle contigs cannot scaffold against nuclear chromosomes.
 
### Phase 5 — Repeat Masking
| Tool | Purpose |
|---|---|
| RepeatModeler | De novo repeat family discovery |
| RepeatMasker | Soft-masks repeats (lowercase) before gene prediction |
 
Expected masking: organelles <5%, nuclear plants 40–85%.
 
### Phase 6 — Structural Annotation *(nuclear mode only)*
| Tool | Mode | Purpose |
|---|---|---|
| Helixer | Nuclear de novo | Deep learning gene prediction (requires sequences ≥21kb) |
| MAKER | Nuclear + reference | Evidence-based prediction using proteins/transcriptome |
 
### Phase 7 — Secondary Metabolites & Defense *(nuclear mode only)*
| Tool | Purpose |
|---|---|
| NLR-Annotator | Disease resistance gene (NBS-LRR) detection |
 
### Phase 8 — Functional Annotation *(nuclear mode only)*
| Tool | Purpose |
|---|---|
| AGAT | Proteome extraction from GFF3 |
| eggNOG-mapper | GO terms, KEGG pathways, COG categories |
 
### Phase 9 — Comparative Genomics *(optional, multi-sample)*
| Tool | Purpose |
|---|---|
| OrthoFinder | Gene family clustering across species |
| MCScanX | Synteny and collinearity detection |
 
Activate with `--run_comparative true`.
 
---
 
## Parameters
 
### Required
| Parameter | Description |
|---|---|
| `--hifi_reads` | PacBio HiFi reads (.fastq.gz) |
| `--genome_type` | `organelle` or `nuclear` |
 
### Nuclear mode
| Parameter | Description |
|---|---|
| `--helixer_models_dir` | Path to Helixer land_plant models (required for de novo mode) |
| `--nlr_jar` | Path to NLR-Annotator JAR file |
| `--nlr_mot` | Path to NLR-Annotator mot.txt |
| `--nlr_store` | Path to NLR-Annotator store.txt |
| `--eggnog_db_dir` | Path to pre-downloaded eggNOG database |
 
### Optional scaffolding
| Parameter | Description |
|---|---|
| `--reference` | Reference genome for RagTag scaffolding — activates MAKER |
| `--hic_map` | Hi-C BAM file for YAHS chromosome scaffolding |
| `--hic_reads` | Hi-C paired reads for Hifiasm phasing |
 
### Optional annotation evidence
| Parameter | Description |
|---|---|
| `--transcriptome` | RNA-seq transcriptome for MAKER evidence |
| `--proteins` | Protein hints for MAKER annotation |
 
### Resource limits
| Parameter | Default | Description |
|---|---|---|
| `--max_memory` | `128.GB` | Maximum memory per process |
| `--max_cpus` | `32` | Maximum CPUs per process |
| `--max_time` | `240.h` | Maximum wall time per process |
 
---
 
## Profiles
 
| Profile | Description |
|---|---|
| `eukaryote_env` | PhytoFlow Docker containers |
| `eukaryote_env,local_dev` | PhytoFlow with reduced resources (20GB RAM, 8 CPUs) |
| `eukaryote_env,aws` | PhytoFlow on AWS Batch |
| `singularity` | HPC Singularity execution |
 
---
 
## Database Setup
 
### Helixer models (required for nuclear de novo)
```bash
mkdir -p /path/to/helixer_models
docker run --rm \
    -v /path/to/helixer_models:/models \
    docker.io/gglyptodon/helixer-docker:helixer_v0.3.3_cuda_11.8.0-cudnn8 \
    fetch_helixer_models.py --lineage land_plant --output-dir /models
```
 
### eggNOG database (required for functional annotation)
```bash
mkdir -p /path/to/eggnog_db
docker run --rm \
    -v /path/to/eggnog_db:/data \
    quay.io/biocontainers/eggnog-mapper:2.1.12--pyhdfd78af_0 \
    download_eggnog_data.py --data_dir /data -y
```
 
---
 
## Test Data
 
Validated on Arabidopsis thaliana:
 
| Dataset | Source | Used for |
|---|---|---|
| Organelle HiFi reads | Zenodo | Organelle mode validation |
| Nuclear HiFi reads (5k subset) | ENA ERR8666127 | Nuclear mode validation |
| Chr4 reference | TAIR10 NC_003075.7 | Reference scaffolding test |
| Protein hints | TAIR10 proteins | MAKER evidence test |
 
### Organelle validation results
```
Chloroplast:    155,667 bp  (expected 154,478 bp — 100.8% complete)
Mitochondrion:  282,616 bp
N50:            146 kb
Contigs:        7
Gaps:           0
Coverage:       chloroplast IR 340-382x, mitochondrion 89x
```
 
### Nuclear validation results (5k reads subset)
```
Contigs ≥21kb:  38 (passed Helixer filter)
Proteins:       527 predicted by Helixer
Pipeline:       13 processes — all green
```
 
---
 
## Output Structure
 
```
results/
├── 01_qc/
│   ├── hifiadapterfilt/     # Adapter-filtered reads
│   └── seqkit_stats/        # Read statistics
├── 02_assembly/
│   ├── hifiasm/             # Raw GFA assembly
│   └── fasta/               # Converted FASTA
├── 03_assembly_qc/
│   ├── quast/               # Assembly statistics
│   ├── busco/               # BUSCO completeness
│   └── coverage/            # Per-contig coverage report
├── 04_scaffolding/          # nuclear mode only
│   ├── yahs/                # Hi-C scaffolds
│   └── ragtag/              # Reference-guided scaffolds
├── 05_repeat_masking/
│   ├── repeatmodeler/       # Repeat library
│   └── repeatmasker/        # Soft-masked assembly
├── 06_annotation/           # nuclear mode only
│   ├── helixer/             # GFF3 gene models (de novo)
│   └── maker/               # GFF3 gene models (reference)
├── 07_secondary/            # nuclear mode only
│   └── nlr_annotator/       # NBS-LRR disease resistance genes
├── 08_functional/           # nuclear mode only
│   └── eggnog/              # GO terms, KEGG, COG annotations
└── 09_comparative/          # --run_comparative true only
    ├── orthofinder/         # Gene family clusters
    └── mcscanx/             # Synteny blocks
```
 
---
 
## Known Limitations (v1.0)
 
| Limitation | Planned fix |
|---|---|
| RepeatModeler used for nuclear | Replace with EDTA v2.0 (better plant TE detection) |
| No TF family classification | Add InterProScan v2.0 (iTAK has no public container) |
| No MultiQC report | Add MultiQC aggregation v2.0 |
| No params.schema.json validation | Add nf-core schema validation v2.0 |
| MAKER not yet validated | Requires RNA-seq test data |
 
---
 
## Citation
 

```
 
---
 
## Author
 
**Naouel El Djouher**
M.Sc. Agrobiotechnology (JLU Giessen) | M.Sc. Molecular Pathology
Full-stack Bioinformatician
 
GitHub: [@NaouelEldjouher](https://github.com/NaouelEldjouher)
 
---
 
## Part of OmniDomain
 
| Pipeline | Kingdom | Status |
|---|---|---|
| metacflow](../metacflow/) |  |
| [FungalFlow](../fungalflow/) | Fungi | 🔧 In development |
| [PhytoFlow](../phytoflow/) | Plants | ✅ v1.0 validated |
