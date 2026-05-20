// subworkflows/local/phytoflow/annotation_functional.nf

include { EGGNOG    } from '../../../modules/local/shared/eggnog/main'


workflow ANNOTATION_FUNCTIONAL {
    take:
    ch_proteins // channel: [ val(meta), path(proteins.fasta) ]

    main:
    ch_versions = Channel.empty()

    // eggNOG-mapper — functional orthology, GO terms, KEGG pathways
    EGGNOG( ch_proteins )
    ch_versions = ch_versions.mix( EGGNOG.out.versions )

    // PlantTFDB  dropped
    // This part is moved to V02

    emit:
    eggnog_txt  = EGGNOG.out.annotations          // [ meta, *.emapper.annotations ]
    versions    = ch_versions
}