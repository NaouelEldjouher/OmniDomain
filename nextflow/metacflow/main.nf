#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
 * ============================================================================
 * OmniDomain — MetaCflow Pipeline
 * Shotgun metagenomics: assembly, binning, taxonomy, annotation, AMR
 * Author: Naouel El Djouher
 * ============================================================================
 *
 * Three execution modes — selected automatically from inputs:
 *
 *   Mode 1 — Illumina short reads only
 *     nextflow run metacflow/main.nf --reads 'data/*_{R1,R2}.fastq.gz'
 *
 *   Mode 2 — ONT long reads only
 *     nextflow run metacflow/main.nf --longreads 'data/sample.fastq.gz'
 *
 *   Mode 3 — Hybrid (Illumina + ONT)
 *     nextflow run metacflow/main.nf --reads '...' --longreads '...'
 * ============================================================================
 */

include { QC_SHORTREAD        } from '../subworkflows/local/shared/qc_shortread'
include { QC_LONGREAD         } from '../subworkflows/local/shared/qc_longread'
include { QC_HYBRID           } from '../subworkflows/local/shared/qc_hybrid'
include { ASSEMBLY_SHORT      } from '../subworkflows/local/metacflow/assembly_short'
include { ASSEMBLY_LONG       } from '../subworkflows/local/metacflow/assembly_long'
include { ASSEMBLY_HYBRID     } from '../subworkflows/local/metacflow/assembly_hybrid'
include { BINNING_METAGENOMIC } from '../subworkflows/local/metacflow/binning_metagenomic'
include { ANNOTATION_AMR      } from '../subworkflows/local/metacflow/annotation_amr'
include { TAXONOMY             } from '../subworkflows/local/metacflow/taxonomy'

workflow {

    // ── A. MODE DETECTION ────────────────────────────────────────────────────
    def has_short = params.reads     ? true : false
    def has_long  = params.longreads ? true : false

    if      ( has_short && has_long ) { log.info ">>> MODE: Hybrid (Illumina + ONT)" }
    else if ( has_short )             { log.info ">>> MODE: Short reads (Illumina)" }
    else if ( has_long  )             { log.info ">>> MODE: Long reads (ONT)" }
    else { error "ERROR: MetaCflow requires --reads and/or --longreads" }

    // ── B. SAMPLE ID + OUTPUT ─────────────────────────────────────────────────
    def sample_id = params.sample_id ?: 'sample'
    log.info ">>> sample_id : ${sample_id}"
    log.info ">>> outdir    : ${params.base_outdir}/metacflow/${sample_id}"

    // ── C. PRE-FLIGHT VALIDATION ──────────────────────────────────────────────
    if ( !params.checkm2_db ) {
        error "ERROR: MetaCflow requires --checkm2_db\nDownload: bash bin/setup_metacflow.sh --only checkm2"
    }

    // ── D. INPUT CHANNELS ────────────────────────────────────────────────────
    def ch_shortreads = has_short
        ? Channel.fromFilePairs( params.reads, checkIfExists: true )
            .map { id, reads -> [ [id: id, single_end: false], reads ] }
        : Channel.empty()

    def ch_longreads = has_long
        ? Channel.fromPath( params.longreads, checkIfExists: true )
            .map { f -> [ [id: f.simpleName, single_end: true], f ] }
        : Channel.empty()

    def ch_checkm2_db = Channel.fromPath( params.checkm2_db, checkIfExists: true )
        .map { f -> [ [id: 'checkm2_db'], f ] }
        .collect()

    // ── E. QC ────────────────────────────────────────────────────────────────
    def ch_qc_short = Channel.empty()
    def ch_qc_long  = Channel.empty()

    if ( has_short && has_long ) {
        QC_HYBRID( ch_shortreads, ch_longreads )
        ch_qc_short = QC_HYBRID.out.short_reads
        ch_qc_long  = QC_HYBRID.out.long_reads
    } else if ( has_short ) {
        QC_SHORTREAD( ch_shortreads )
        ch_qc_short = QC_SHORTREAD.out.reads
    } else {
        QC_LONGREAD( ch_longreads )
        ch_qc_long = QC_LONGREAD.out.reads
    }

    // ── E2. TAXONOMY — read-level classification ─────────────────────────────
    // Kraken2 classifies reads against a reference database
    // Bracken re-estimates abundances at species level
    if ( params.kraken2_db ) {
        def ch_tax_reads = has_short ? ch_qc_short : ch_qc_long
        TAXONOMY( ch_tax_reads, params.kraken2_db )
    } else {
        log.info "INFO: Taxonomy skipped — set --kraken2_db to enable"
    }

    // ── F. ASSEMBLY ──────────────────────────────────────────────────────────
    def ch_assembly      = Channel.empty()
    def ch_mapping_reads = Channel.empty()

    if ( has_short && has_long ) {
        ASSEMBLY_HYBRID( ch_qc_short, ch_qc_long )
        ch_assembly      = ASSEMBLY_HYBRID.out.assembly
        ch_mapping_reads = ch_qc_short
    } else if ( has_short ) {
        ASSEMBLY_SHORT( ch_qc_short )
        ch_assembly      = ASSEMBLY_SHORT.out.assembly
        ch_mapping_reads = ch_qc_short
    } else {
        ASSEMBLY_LONG( ch_qc_long )
        ch_assembly      = ASSEMBLY_LONG.out.assembly
        ch_mapping_reads = ch_qc_long
    }

    // ── G. BINNING ────────────────────────────────────────────────────────────
    // MetaBAT2 bins contigs into MAGs
    // CheckM2 filters for high-quality bins (completeness ≥50%, contamination ≤10%)
    BINNING_METAGENOMIC( ch_assembly, ch_mapping_reads, ch_checkm2_db )

    // ── H. ANNOTATION + AMR ───────────────────────────────────────────────────
    // Prokka annotates each high-quality MAG
    // ResFinder detects AMR genes (shared module with NextAMR)
    if ( params.resfinder_db ) {
        ANNOTATION_AMR(
            BINNING_METAGENOMIC.out.filtered_mags,
            params.resfinder_db
        )
    } else {
        log.info "INFO: AMR annotation skipped — set --resfinder_db to enable"
    }

}
