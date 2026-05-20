#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

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
    // A. Parse Inputs using pure POSIX absolute paths
    ch_shortreads = params.shortreads ? Channel.fromFilePairs(params.shortreads, checkIfExists: true).map { id, reads -> [ [id: id], reads ] } : Channel.empty()
    ch_longreads  = params.longreads ? Channel.fromPath(params.longreads, checkIfExists: true).map { file -> [ [id: file.baseName], file ] } : Channel.empty()
    
    // Format RNA-seq to pass an empty array tuple instead of a completely empty channel if parameter is omitted
    ch_rnaseq     = params.rnaseq_bam ? Channel.fromPath(params.rnaseq_bam, checkIfExists: true).map { file -> [ [id: 'rna_evidence'], file ] } : Channel.of([[], []])

    // B. Quality Control & Assembly Routing
    // Pre-execute shortread QC if shortreads are provided for either path
    if (params.shortreads) {
        QC_SHORTREAD( ch_shortreads )
    }
    
    if (params.shortreads && !params.longreads) {
        ASSEMBLY_FUNGAL( Channel.empty(), QC_SHORTREAD.out.reads, params.busco_db )
        
    } else if (params.longreads) {
        QC_LONGREAD( ch_longreads )
        
        // Safely assign the channel out variable without inline function nesting
        ch_resolved_short = params.shortreads ? QC_SHORTREAD.out.reads : Channel.empty()
        
        ASSEMBLY_FUNGAL( QC_LONGREAD.out.reads, ch_resolved_short, params.busco_db ) 
    } else {
        error "PIPELINE ERROR: Please provide --shortreads or --longreads to run FungalFlow!"
    }

    // FIXED: Extract the assembly output into the global workflow pool *outside* of the conditional scopes
    ch_draft_assembly = ASSEMBLY_FUNGAL.out.assembly

    // C. Structural Annotation Pipeline
    REPEAT_MASKING( ch_draft_assembly )
    
    // Convert path to a channel-safe file pointer or an empty array so nextflow doesn't choke
    ch_protein_hints = params.protein_hints ? Channel.fromPath(params.protein_hints, checkIfExists: true).collect() : []
    
    // Execute structural annotations using our safe, synchronized parameters
    ANNOTATION_STRUCTURAL(
        REPEAT_MASKING.out.masked_fasta,
        ch_protein_hints,
        ch_rnaseq
    )

    // D. Functional Profiling & Secretome Parsing
    ch_predicted_proteins = ANNOTATION_STRUCTURAL.out.proteins

    ANNOTATION_FUNCTIONAL( ch_predicted_proteins )
    SECRETOME( ch_predicted_proteins )
}