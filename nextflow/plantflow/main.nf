#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
 * 1. IMPORT SHARED CORE SUBWORKFLOWS
 */
include { QC_LONGREAD    } from '../subworkflows/local/shared/qc_longread'
include { REPEAT_MASKING } from '../subworkflows/local/shared/repeat_masking'

/*
 * 2. IMPORT PLANT-SPECIFIC SUBWORKFLOWS
 */
include { ASSEMBLY_PLANT        } from '../subworkflows/local/plantflow/assembly_plant'
include { SCAFFOLDING           } from '../subworkflows/local/plantflow/scaffolding'
include { ANNOTATION_STRUCTURAL } from '../subworkflows/local/plantflow/annotation_structural'
include { ANNOTATION_FUNCTIONAL } from '../subworkflows/local/plantflow/annotation_functional'
include { SECONDARY_METABOLITES } from '../subworkflows/local/plantflow/secondary_metabolites'

/*
 * 3. MAIN WORKFLOW EXECUTION
 */
workflow {
    // A. Parse Inputs
    ch_longreads = params.longreads ? Channel.fromPath(params.longreads, checkIfExists: true).map { file -> [ [id: file.baseName], file ] } : Channel.empty()
    ch_hic_reads = params.hic_reads ? Channel.fromFilePairs(params.hic_reads, checkIfExists: true).map { id, reads -> [ [id: id], reads ] } : Channel.empty()
    
    // B. Quality Control & Assembly
    if (!params.longreads) { error "PIPELINE ERROR: Plant genomes require --longreads (PacBio/ONT)!" }
    
    QC_LONGREAD( ch_longreads )
    
    ASSEMBLY_PLANT( QC_LONGREAD.out.reads, ch_hic_reads )

    // C. Scaffolding (Upgrade contigs to chromosomes)
    SCAFFOLDING(
        ASSEMBLY_PLANT.out.assembly,
        params.hic_map ?: Channel.empty(),
        params.reference ?: Channel.empty()
    )

    // D. Masking & Annotation
    REPEAT_MASKING( SCAFFOLDING.out.scaffolds )
    
    ANNOTATION_STRUCTURAL(
        REPEAT_MASKING.out.masked_fasta,
        params.transcriptome ?: Channel.empty(),
        params.proteins ?: Channel.empty()
    )

    // E. Defense Networks & Functional Mapping
    // Note: We use Helixer's GFF output for the antiSMASH/NLR runs
    SECONDARY_METABOLITES( SCAFFOLDING.out.scaffolds, ANNOTATION_STRUCTURAL.out.helixer_gff )
    ANNOTATION_FUNCTIONAL( ANNOTATION_STRUCTURAL.out.maker_gff ) 
}