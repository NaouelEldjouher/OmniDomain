include { PROKKA     } from '../../../modules/local/metacflow/prokka/main'
include { RESFINDER  } from '../../../modules/local/shared/resfinder/main'

workflow ANNOTATION_AMR {

    take:
    ch_filtered_mags  // [ val(meta), path(fasta) ] — high-quality MAGs from CheckM2
    resfinder_db      // path to ResFinder database

    main:
    ch_versions = Channel.empty()

    // Prokka — structural annotation of each MAG
    PROKKA( ch_filtered_mags )
    ch_versions = ch_versions.mix( PROKKA.out.versions )

    // ResFinder — AMR gene detection (shared with NextAMR)
    def ch_resfinder_input = ch_filtered_mags
        .map { meta, fasta -> [ meta, fasta, [], [] ] }

    RESFINDER( ch_resfinder_input, resfinder_db )
    ch_versions = ch_versions.mix( RESFINDER.out.versions )

    emit:
    gff      = PROKKA.out.gff       // [ meta, gff ] — gene annotations
    amr      = RESFINDER.out.results // [ meta, txt ] — AMR genes
    versions = ch_versions
}
