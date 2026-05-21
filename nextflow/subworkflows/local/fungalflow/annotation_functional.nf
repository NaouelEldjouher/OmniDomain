// subworkflows/local/fungalflow/annotation_functional.nf

/*
 * Include custom functional annotation local wrappers
 */
include { EGGNOG } from '../../../modules/local/shared/eggnog/main'
include { DBCAN  } from '../../../modules/local/fungalflow/dbcan/main'

workflow ANNOTATION_FUNCTIONAL {
    take:
    ch_proteins // channel: [ val(meta), path(proteins.fasta) ]

    main:
    ch_versions = Channel.empty()

    // 1. Run eggNOG-mapper for functional annotation transferring
    EGGNOG ( ch_proteins )
    ch_eggnog_annotations = EGGNOG.out.annotations
    ch_versions           = ch_versions.mix(EGGNOG.out.versions)

    // 2. Run dbCAN to annotate and profile Carbohydrate-Active Enzymes (CAZymes)
    DBCAN ( ch_proteins )
    ch_dbcan_outputs = DBCAN.out.overview
    ch_versions      = ch_versions.mix(DBCAN.out.versions)

    emit:
    eggnog_txt = ch_eggnog_annotations // channel: [ val(meta), path(*.emapper.annotations) ]
    dbcan_tsv  = ch_dbcan_outputs      // channel: [ val(meta), path(*.overview.txt) ]
    versions   = ch_versions           // channel: [ path(versions.yml) ]
}