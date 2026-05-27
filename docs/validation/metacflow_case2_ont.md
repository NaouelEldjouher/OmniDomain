# MetaCflow Case 2 — ONT Long Reads

**Dataset:** SRR13128014 · 3,000 ONT reads · up to 32kb
**Date:** 2026-05-27
**Status:** 10/10 processes green

## Results

**QC:** Filtlong + NanoPlot — 3,000 reads, 26.1Mb retained

**Assembly (Flye --meta):** 40 contigs · N50 19.5kb · largest 167kb · mean coverage 3x

**Taxonomy (Kraken2 + Bracken):** 99.86% classified
- Bacillota (Firmicutes): 47.4%
- Bacteroidota: 26.4%
- Classic gut microbiome profile

**Binning (MetaBAT2 + CheckM2):** 0 MAGs — expected at 3x mean coverage (need >=10x). CheckM2 skipped gracefully.

## Output
01_qc/filtlong, 01_qc/nanoplot, 02_assembly/flye, 03_binning/metabat2, 04_bin_qc/checkm2, 05_taxonomy/kraken2, 05_taxonomy/bracken
