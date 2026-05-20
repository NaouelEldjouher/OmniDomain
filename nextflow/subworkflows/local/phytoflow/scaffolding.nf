// subworkflows/local/plantflow/scaffolding.nf

include { YAHS   } from '../../../modules/local/phytoflow/yahs/main'
include { RAGTAG } from '../../../modules/local/phytoflow/ragtag/main'

workflow SCAFFOLDING {
    take:
    ch_assembly
    ch_hic_map
    ch_ref

    main:
    ch_versions          = Channel.empty()
    ch_current_scaffolds = ch_assembly  
    if ( params.hic_map ) {
        log.info "INFO: Hi-C map provided — running YAHS"
        YAHS( ch_assembly, ch_hic_map )
        ch_current_scaffolds = YAHS.out.scaffolds
        ch_versions          = ch_versions.mix( YAHS.out.versions )
    } else {
        log.info "INFO: No --hic_map provided — YAHS skipped"
    }

    if ( params.reference ) {
        log.info "INFO: Reference provided — running RagTag"
        RAGTAG( ch_current_scaffolds, ch_ref )
        ch_current_scaffolds = RAGTAG.out.scaffolds
        ch_versions          = ch_versions.mix( RAGTAG.out.versions )
    } else {
        log.info "INFO: No --reference provided — RagTag skipped"
    }

    if ( !params.hic_map && !params.reference ) {
        log.info "INFO: No scaffolding tools ran — assembly passed through unchanged"
        log.info "INFO: Provide --reference for RagTag or --hic_map for YAHS"
    }

    emit:
    scaffolds = ch_current_scaffolds  
    versions  = ch_versions
}