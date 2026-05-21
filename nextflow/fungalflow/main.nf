#!/usr/bin/env nextflow
nextflow.enable.dsl = 2


/*
* ============================================================================
* OmniDomain — FungalFlow Pipeline
* Fungal genome assembly, annotation & secondary metabolite detection
* Author: Naouel El Djouher
* ============================================================================
*
* Three execution modes — selected automatically from input reads provided:
*
*   Mode 1 — Short reads only (Illumina)
*     nextflow run fungalflow/main.nf --shortreads 'reads_{1,2}.fastq.gz'
*     Runs: FastP QC → SPAdes → QUAST/BUSCO → RepeatMasking → Funannotate
*
*   Mode 2 — Long reads only (ONT)
*     nextflow run fungalflow/main.nf --longreads 'reads.fastq.gz'
*     Runs: Filtlong + NanoPlot QC → Flye → QUAST/BUSCO → RepeatMasking → BRAKER3
*
*   Mode 3 — Hybrid (Illumina + ONT)
*     nextflow run fungalflow/main.nf --shortreads 'reads_{1,2}.fastq.gz' \
*                                     --longreads 'reads.fastq.gz'
*     Runs: Both QC → SPAdes hybrid → QUAST/BUSCO → RepeatMasking → Funannotate
* ============================================================================
*/

/*
 * 1. IMPORT SHARED CORE SUBWORKFLOWS (Hopping up to local/shared)
 */
include { QC_SHORTREAD   } from '../subworkflows/local/shared/qc_shortread'
include { QC_LONGREAD    } from '../subworkflows/local/shared/qc_longread'
include { REPEAT_MASKING } from '../subworkflows/local/shared/repeat_masking'
include { ASSEMBLY_FUNGAL       } from '../subworkflows/local/fungalflow/assembly_fungal'
include { ANNOTATION_STRUCTURAL } from '../subworkflows/local/fungalflow/annotation_structural'
include { ANNOTATION_FUNCTIONAL } from '../subworkflows/local/fungalflow/annotation_functional'
include { SECRETOME             } from '../subworkflows/local/fungalflow/secretome'
include { SECONDARY_METABOLITES } from '../subworkflows/local/fungalflow/secondary_metabolites'
include { COMPARATIVE_FUNGAL } from '../subworkflows/local/fungalflow/comparative_fungal'
/*
 * 3. MAIN WORKFLOW EXECUTION
 */
workflow {
// ── A. AUTO-DETECTION: determine assembly mode from inputs ──────────────
def has_short  = params.shortreads  ? true : false
def has_long   = params.longreads   ? true : false
def has_hybrid = ( has_short && has_long )
if      ( has_hybrid ) log.info ">>> MODE: Hybrid — Illumina + ONT → SPAdes hybrid"
else if ( has_short  ) log.info ">>> MODE: Short reads only — Illumina → SPAdes"
else if ( has_long   ) log.info ">>> MODE: Long reads only — ONT → Flye"
else error "PIPELINE ERROR: FungalFlow requires --shortreads and/or --longreads"

log.info ">>> shortreads : ${params.shortreads ?: 'not provided'}"
log.info ">>> longreads  : ${params.longreads  ?: 'not provided'}"
log.info ">>> rnaseq_bam : ${params.rnaseq_bam ?: 'not provided'}"


// ── C. INPUT PARSING ─────────────────────────────────────────────────────
// Short reads — Illumina paired-end
ch_shortreads = has_short
? Channel.fromFilePairs( params.shortreads, checkIfExists: true )
.map { id, reads -> [ [id: id], reads ] }
: Channel.empty()

ch_longreads = has_long
? Channel.fromPath( params.longreads, checkIfExists: true )
.map { f -> [ [id: f.simpleName], f ] }
: Channel.empty()

ch_rnaseq = params.rnaseq_bam
? Channel.fromPath( params.rnaseq_bam, checkIfExists: true )
.map { f -> [ [id: 'rna_evidence'], f ] }
: Channel.of( [ [id: 'rna_empty'], [] ] )

ch_protein_hints = params.protein_hints
? Channel.fromPath( params.protein_hints, checkIfExists: true )
.map { f -> [ [id: 'prot_hints'], f ] }
: Channel.of( [ [id: 'prot_empty'], [] ] )


// ── D. QC ────────────────────────────────────────────────────────────────
// FastP: adapter trimming + quality filtering for Illumina
// Filtlong + NanoPlot: quality filtering + statistics for ONT
if ( has_short ) {
QC_SHORTREAD( ch_shortreads )
}
if ( has_long ) {
QC_LONGREAD( ch_longreads )
}
ch_qc_short = has_short ? QC_SHORTREAD.out.reads : Channel.empty()
ch_qc_long  = has_long  ? QC_LONGREAD.out.reads  : Channel.empty()
// ── E. ASSEMBLY ──────────────────────────────────────────────────────────
// Mode 1 — short only: SPAdes
// Mode 2 — long only:  Flye
// Mode 3 — hybrid:     SPAdes hybrid (Illumina accuracy + ONT contiguity)
// ASSEMBLY_FUNGAL subworkflow handles routing internally

ASSEMBLY_FUNGAL(
ch_qc_short,
ch_qc_long,
has_short,
has_long
)

// ── F. REPEAT MASKING ────────────────────────────────────────────────────
// RepeatModeler: de novo repeat family discovery
// RepeatMasker: soft-mask repeats — required before gene prediction
// Expected masking: fungal genomes 5–20%
REPEAT_MASKING( ASSEMBLY_FUNGAL.out.assembly )

// ── G. STRUCTURAL ANNOTATION ─────────────────────────────────────────────
// Short/hybrid mode: Funannotate (all-in-one fungal annotation)
// Long-read mode:    BRAKER3 (evidence-based, works without RNA-seq)
// Both accept protein hints and RNA-seq evidence when provided
ANNOTATION_STRUCTURAL(
REPEAT_MASKING.out.masked_fasta,
ch_protein_hints,
ch_rnaseq
)

// ── H. SECONDARY METABOLITES ─────────────────────────────────────────────
// antiSMASH: BGC detection — terpenes, PKS, NRPS, RiPPs
// Requires annotation GFF for full cluster context
SECONDARY_METABOLITES(
REPEAT_MASKING.out.masked_fasta,
ANNOTATION_STRUCTURAL.out.gff
)

// ── I. FUNCTIONAL ANNOTATION ─────────────────────────────────────────────
// eggNOG-mapper: GO terms, KEGG pathways, COG categories
// dbCAN: CAZyme annotation (GH, GT, PL, CE, AA families)
ANNOTATION_FUNCTIONAL( ANNOTATION_STRUCTURAL.out.proteins )

// ── J. SECRETOME PREDICTION ──────────────────────────────────────────────
// SignalP: signal peptide prediction → secreted proteins
// Relevant for industrial enzyme discovery
SECRETOME( ANNOTATION_STRUCTURAL.out.proteins )
}

// ── K. COMPARATIVE GENOMICS ──────────────────────────────────
// OrthoFinder: gene family clustering across multiple fungal genomes
// CAFE5: gene family expansion/contraction analysis
// IQ-TREE2: maximum likelihood species tree
// Activate with: --run_comparative true
// Requires: multiple samples — single sample produces no orthogroups
if ( params.run_comparative ) {
ch_collected_proteomes = ANNOTATION_STRUCTURAL.out.proteins
.map { meta, fasta -> fasta }
.collect()

ch_collected_gffs = ANNOTATION_STRUCTURAL.out.gff
.map { meta, gff -> gff }
.collect()

COMPARATIVE_FUNGAL( ch_collected_proteomes, ch_collected_gffs )
} else {
log.info "INFO: Comparative genomics skipped — use --run_comparative true to enable"
log.info "INFO: Requires multiple samples submitted together"
}
