#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
 * 1. IMPORT SHARED CORE SUBWORKFLOWS
 */
include { QC_SHORTREAD } from '../subworkflows/local/shared/qc_shortread'
include { QC_LONGREAD  } from '../subworkflows/local/shared/qc_longread'
include { QC_HYBRID    } from '../subworkflows/local/shared/qc_hybrid'

/*
 * 2. IMPORT NEXTAMR-SPECIFIC SUBWORKFLOWS
 */
include { ASSEMBLY_SHORT  } from '../subworkflows/local/nextamr/assembly_short'
include { ASSEMBLY_LONG   } from '../subworkflows/local/nextamr/assembly_long'
include { ASSEMBLY_HYBRID } from '../subworkflows/local/nextamr/assembly_hybrid'
include { POLISHING       } from '../subworkflows/local/nextamr/polishing'
include { ANNOTATION_AMR  } from '../subworkflows/local/nextamr/annotation_amr'

/*
 * 3. MAIN WORKFLOW EXECUTION BLOCK
 */
workflow {
    // A. Parse Inputs into Nextflow Channels
    ch_shortreads = params.reads ? Channel.fromFilePairs(params.reads, checkIfExists: true).map { id, reads -> [ [id: id, single_end: false], reads ] } : Channel.empty()
    ch_longreads  = params.longreads ? Channel.fromPath(params.longreads, checkIfExists: true).map { file -> [ [id: file.baseName, single_end: true], file ] } : Channel.empty()
    
    ch_polished_assembly = Channel.empty()

    // B. Core Routing Logic
    if (params.reads && params.longreads) {
        // --- HYBRID PIPELINE PATH ---
        QC_HYBRID ( ch_shortreads, ch_longreads )
        ASSEMBLY_HYBRID ( QC_HYBRID.out.short_reads, QC_HYBRID.out.long_reads )
        POLISHING ( ASSEMBLY_HYBRID.out.assembly, QC_HYBRID.out.long_reads, QC_HYBRID.out.short_reads )
        ch_polished_assembly = POLISHING.out.polished_assembly

    } else if (params.reads && !params.longreads) {
        // --- SHORT-READ ONLY PATH ---
        QC_SHORTREAD ( ch_shortreads )
        ASSEMBLY_SHORT ( QC_SHORTREAD.out.reads )
        POLISHING ( ASSEMBLY_SHORT.out.assembly, Channel.empty(), QC_SHORTREAD.out.reads )
        ch_polished_assembly = POLISHING.out.polished_assembly

    } else if (!params.reads && params.longreads) {
        // --- LONG-READ ONLY PATH ---
        QC_LONGREAD ( ch_longreads )
        ASSEMBLY_LONG ( QC_LONGREAD.out.reads )
        POLISHING ( ASSEMBLY_LONG.out.assembly, QC_LONGREAD.out.reads, Channel.empty() )
        ch_polished_assembly = POLISHING.out.polished_assembly

    } else {
        error "PIPELINE ERROR: You must provide --reads (Illumina), --longreads (ONT/PacBio), or both!"
    }

    // C. Final Bacterial Annotation & AMR Profiling
    ANNOTATION_AMR (
        ch_polished_assembly,
        params.bakta_db,
        params.amrfinder_db
    )
}