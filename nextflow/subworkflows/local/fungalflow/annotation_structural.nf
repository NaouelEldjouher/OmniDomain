include { BRAKER3     } from '../../../modules/local/shared/braker3/main'
include { FUNANNOTATE } from '../../../modules/local/fungalflow/funannotate/main'

workflow ANNOTATION_STRUCTURAL {

    take:
    ch_masked_assembly
    ch_protein_hints
    ch_rnaseq_bam

    main:
    ch_versions       = Channel.empty()
    ch_annotation_gff = Channel.empty()
    ch_proteins       = Channel.empty()

    if ( !params.longreads || params.shortreads ) {
        log.info "INFO: Funannotate — short/hybrid read mode"
        FUNANNOTATE( ch_masked_assembly, ch_protein_hints, ch_rnaseq_bam )
        ch_annotation_gff = FUNANNOTATE.out.gff3
        ch_proteins       = FUNANNOTATE.out.proteins
        ch_versions       = ch_versions.mix( FUNANNOTATE.out.versions )
    } else if ( params.longreads && !params.shortreads ) {
        log.info "INFO: BRAKER3 — long read only mode"
        BRAKER3( ch_masked_assembly, ch_protein_hints )
        ch_annotation_gff = BRAKER3.out.gff
        ch_proteins       = BRAKER3.out.proteins
        ch_versions       = ch_versions.mix( BRAKER3.out.versions )
    }

    emit:
    gff      = ch_annotation_gff
    proteins = ch_proteins
    versions = ch_versions

}
