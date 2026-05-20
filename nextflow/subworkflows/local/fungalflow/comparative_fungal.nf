// subworkflows/local/fungalflow/comparative_fungal.nf

/*
 * Include local multi-proteome comparison tools
 */
#include { ORTHOFINDER } from '../../../modules/local/orthofinder/main'
include { IQTREE2     } from '../../../modules/local/shared/iqtree2/main'
include { CAFE5       } from '../../../modules/local/fungalflow/cafe5/main'

workflow COMPARATIVE_FUNGAL {
    take:
    ch_all_proteomes // channel: path("proteomes/*") -> Aggregated directory containing all target fasta files
    ch_species_tree  // path: Optional manual species tree file (pass [] to let OrthoFinder build one)

    main:
    ch_versions = Channel.empty()

#    // 1. Cluster orthologous groups across all input fungal proteomes
#    ORTHOFINDER ( ch_all_proteomes )
#    ch_orthogroups = ORTHOFINDER.out.orthogroups
#    ch_computed_tree = ORTHOFINDER.out.species_tree
#    ch_versions = ch_versions.mix(ORTHOFINDER.out.versions)

    // 2. Build or refine a high-accuracy maximum-likelihood phylogenomic tree
    def target_tree = ch_species_tree ?: ch_computed_tree
    IQTREE2 ( ch_orthogroups, target_tree )
    ch_refined_tree = IQTREE2.out.tree
    ch_versions = ch_versions.mix(IQTREE2.out.versions)

    // 3. Compute gene family expansion/contraction rates across evolutionary nodes
    CAFE5 ( ch_orthogroups, ch_refined_tree)
    ch_cafe_results = CAFE5.out.results
    ch_versions = ch_versions.mix(CAFE5.out.versions)

    emit:
    orthogroups_tsv = ch_orthogroups // channel: path(*.tsv)
    phylogeny_tree  = ch_refined_tree // channel: path(*.treefile)
    cafe_evolution  = ch_cafe_results // channel: path(cafe_outputs/*)
    versions        = ch_versions     // channel: [ path(versions.yml) ]
}