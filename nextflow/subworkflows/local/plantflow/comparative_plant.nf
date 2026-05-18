// subworkflows/local/plantflow/comparative_plant.nf

include { ORTHOFINDER } from '../../../modules/local/orthofinder/main'
include { MCSCANX     } from '../../../modules/local/mcscanx/main'

workflow COMPARATIVE_PLANT {
    take:
    ch_all_proteomes // channel: path("proteomes/*") -> Aggregated proteomes
    ch_all_gffs      // channel: path("gffs/*")      -> Aggregated GFFs for structural mapping

    main:
    ch_versions = Channel.empty()

    // 1. Cluster orthologous groups across all plant species
    ORTHOFINDER ( ch_all_proteomes )
    ch_orthogroups = ORTHOFINDER.out.orthogroups
    ch_versions = ch_versions.mix(ORTHOFINDER.out.versions)

    // 2. Compute collinearity and synteny blocks across chromosomes
    MCSCANX ( ch_all_proteomes, ch_all_gffs )
    ch_synteny = MCSCANX.out.synteny
    ch_versions = ch_versions.mix(MCSCANX.out.versions)

    emit:
    orthogroups = ch_orthogroups // channel: path(*.tsv)
    synteny     = ch_synteny     // channel: path(*.collinearity)
    versions    = ch_versions    // channel: [ path(versions.yml) ]
}