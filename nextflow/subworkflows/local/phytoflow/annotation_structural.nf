// ============================================================================
// subworkflows/local/plantflow/annotation_structural.nf
// ============================================================================

include { HELIXER } from '../../../modules/local/helixer/phytoflow/main'
include { BRAKER3 } from '../../../modules/local/braker3/phytoflow/main'

workflow ANNOTATION_STRUCTURAL {
    take:
    ch_scaffolds
    ch_transcriptome
    ch_proteins
    do_helixer    // ← receives true/false from main.nf
    do_maker      // ← receives true/false from main.nf

    main:
    ch_versions    = Channel.empty()
    ch_helixer_gff = Channel.empty()
    ch_maker_gff   = Channel.empty()

    if ( !do_helixer && !do_maker ) {
        log.info "INFO: No structural annotation will run (do_helixer=${do_helixer}, do_maker=${do_maker})"
        log.info "INFO: Set --genome_type nuclear for annotation"
    }

    if ( do_helixer ) {          // ← NOT params.run_helixer
        HELIXER( ch_scaffolds )
        ch_helixer_gff = HELIXER.out.gff
        ch_versions    = ch_versions.mix( HELIXER.out.versions )
    } else {
        log.info "INFO: Helixer skipped"
    }

    if ( do_maker ) {
    BRAKER3( ch_scaffolds, ch_proteins )
    ch_maker_gff = BRAKER3.out.gff   
    ch_versions  = ch_versions.mix( BRAKER3.out.versions )
    } else {
    log.info "INFO: BRAKER3 skipped"
    }
    emit:
    helixer_gff = ch_helixer_gff
    maker_gff   = ch_maker_gff  
    versions    = ch_versions
}