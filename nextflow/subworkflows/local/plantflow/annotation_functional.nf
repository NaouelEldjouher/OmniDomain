// subworkflows/local/plantflow/annotation_functional.nf

include { EGGNOG    } from '../../../modules/local/eggnog/main'
include { PLANTTFDB } from '../../../modules/local/planttfdb/main'

workflow ANNOTATION_FUNCTIONAL {
    take:
    ch_proteins // channel: [ val(meta), path(proteins.fasta) ]

    main:
    ch_versions = Channel.empty()

    // 1. Broad functional orthology and GO term mapping
    EGGNOG ( ch_proteins )
    ch_versions = ch_versions.mix(EGGNOG.out.versions)

    // 2. Identify plant-specific transcription factors
    PLANTTFDB ( ch_proteins )
    ch_versions = ch_versions.mix(PLANTTFDB.out.versions)

    emit:
    eggnog_txt  = EGGNOG.out.annotations  // channel: [ val(meta), path(*.emapper.annotations) ]
    planttf_tsv = PLANTTFDB.out.results   // channel: [ val(meta), path(*.tsv) ]
    versions    = ch_versions             // channel: [ path(versions.yml) ]
}