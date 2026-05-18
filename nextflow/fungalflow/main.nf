#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
 * 1. IMPORT SHARED CORE SUBWORKFLOWS
 */
include { QC_SHORTREAD   } from '../subworkflows/local/shared/qc_shortread'
include { QC_LONGREAD    } from '../subworkflows/local/shared/qc_longread'
include { REPEAT_MASKING } from '../subworkflows/local/shared/repeat_masking'

/*
 * 2. IMPORT FUNGAL-SPECIFIC SUBWORKFLOWS
 */
include { ASSEMBLY_FUNGAL       } from '../subworkflows/local/fungalflow/assembly_fungal'
include { ANNOTATION_STRUCTURAL } from '../subworkflows/local/fungalflow/annotation_structural'
include { ANNOTATION_FUNCTIONAL } from '../subworkflows/local/fungalflow/annotation_functional'
include { SECRETOME             } from '../subworkflows/local/fungalflow/secretome'

/*
 * 3. MAIN WORKFLOW EXECUTION
 */
workflow {
    // A. Parse Inputs
    ch_shortreads = params.shortreads ? Channel.fromFilePairs(params.shortreads, checkIfExists: true).map { id, reads -> [ [id: id], reads ] } : Channel.empty()
    ch_longreads  = params.longreads ? Channel.fromPath(params.longreads, checkIfExists: true).map { file -> [ [id: file.baseName], file ] } : Channel.empty()
    ch_rnaseq     = params.rnaseq_bam ? Channel.fromPath(params.rnaseq_bam, checkIfExists: true).map { file -> [ [id: 'rna_evidence'], file ] } : Channel.empty()

    // B. Quality Control & Assembly Routing
    ch_draft_assembly = Channel.empty()
    if (params.shortreads && !params.longreads) {
        QC_SHORTREAD( ch_shortreads )
        ASSEMBLY_FUNGAL( Channel.empty(), QC_SHORTREAD.out.reads, params.busco_db )
        ch_draft_assembly = ASSEMBLY_FUNGAL.out.assembly
    } else if (params.longreads) {
        QC_LONGREAD( ch_longreads )
        // Fungal long-read/hybrid fallback
        ASSEMBLY_FUNGAL( QC_LONGREAD.out.reads, ch_shortreads, params.busco_db ) 
        ch_draft_assembly = ASSEMBLY_FUNGAL.out.assembly
    } else {
        error "PIPELINE ERROR: Please provide --shortreads or --longreads to run FungalFlow!"
    }

    // C. Structural Annotation Pipeline
    REPEAT_MASKING( ch_draft_assembly )
    
    ANNOTATION_STRUCTURAL(
        REPEAT_MASKING.out.masked_fasta,
        params.protein_hints,
        ch_rnaseq
    )

    // D. Functional Profiling
    ANNOTATION_FUNCTIONAL( ANNOTATION_STRUCTURAL.out.proteins )
    SECRETOME( ANNOTATION_STRUCTURAL.out.proteins )
}