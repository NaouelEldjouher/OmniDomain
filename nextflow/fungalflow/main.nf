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

/*
 * 2. IMPORT FUNGAL-SPECIFIC SUBWORKFLOWS (Sitting right inside your current directory tree)
 */
include { ASSEMBLY_FUNGAL       } from '../subworkflows/local/fungalflow/assembly_fungal'
include { ANNOTATION_STRUCTURAL } from '../subworkflows/local/fungalflow/annotation_structural'
include { ANNOTATION_FUNCTIONAL } from '../subworkflows/local/fungalflow/annotation_functional'
include { SECRETOME             } from '../subworkflows/local/fungalflow/secretome'

/*
 * 3. MAIN WORKFLOW EXECUTION
 */
workflow {
// ── A. AUTO-DETECTION: determine assembly mode from inputs ──────────────
// Local Groovy variables — evaluated at runtime from resolved params
// params are immutable after launch — never assign inside workflow {}
def has_short  = params.shortreads  ? true : false
def has_long   = params.longreads   ? true : false
def has_hybrid = ( has_short && has_long )
if ( has_hybrid ) {
log.info ">>> MODE: Hybrid — Illumina + ONT → SPAdes hybrid assembly"
} else if ( has_short ) {
log.info ">>> MODE: Short reads only — Illumina → SPAdes assembly"
    } else if ( has_long ) {
log.info ">>> MODE: Long reads only — ONT → Flye assembly"
} else {
error "PIPELINE ERROR: FungalFlow requires --shortreads and/or --longreads"
}

log.info ">>> shortreads : ${params.shortreads ?: 'not provided'}"
log.info ">>> longreads  : ${params.longreads  ?: 'not provided'}"
log.info ">>> rnaseq_bam : ${params.rnaseq_bam ?: 'not provided'}"


// ── B. PRE-FLIGHT VALIDATION ─────────────────────────────────────────────
if ( has_long && params.rnaseq_bam ) {
def rna = file(params.rnaseq_bam)
if ( !rna.exists() ) {
exit 1, "PIPELINE ERROR: rnaseq_bam file not found: ${params.rnaseq_bam}"
}
}

// ── C. INPUT PARSING ─────────────────────────────────────────────────────
// Short reads — Illumina paired-end
ch_shortreads = has_short
? Channel
.fromFilePairs( params.shortreads, checkIfExists: true )
.map { id, reads -> [ [id: id], reads ] }
: Channel.empty()

// Long reads — ONT single-file
ch_longreads = has_long
? Channel
.fromPath( params.longreads, checkIfExists: true )
.map { f -> [ [id: f.simpleName], f ] }
: Channel.empty()

// RNA-seq BAM — optional evidence for BRAKER3/Funannotate
ch_rnaseq = params.rnaseq_bam
? Channel
.fromPath( params.rnaseq_bam, checkIfExists: true )
.map { f -> [ [id: 'rna_evidence'], f ] }
: Channel.of( [ [id: 'rna_empty'], [] ] )

// Protein hints — optional evidence for annotation
ch_protein_hints = params.protein_hints
? Channel
.fromPath( params.protein_hints, checkIfExists: true )
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

// ── E. ASSEMBLY ──────────────────────────────────────────────────────────
// Mode 1 — short only: SPAdes
// Mode 2 — long only:  Flye
// Mode 3 — hybrid:     SPAdes hybrid (Illumina accuracy + ONT contiguity)
// ASSEMBLY_FUNGAL subworkflow handles routing internally
ch_qc_short = has_short ? QC_SHORTREAD.out.reads : Channel.empty()
ch_qc_long  = has_long  ? QC_LONGREAD.out.reads  : Channel.empty()

ASSEMBLY_FUNGAL(
ch_qc_short,
ch_qc_long
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
ch_rnaseq,
has_short,   // do_funannotate — local variable, not param
has_long     // do_braker3     — local variable, not param
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
