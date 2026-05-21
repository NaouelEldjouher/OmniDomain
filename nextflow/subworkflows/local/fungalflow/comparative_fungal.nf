// subworkflows/local/fungalflow/comparative_fungal.nf

/*
 * Include local multi-proteome comparison tools
 */
include { ORTHOFINDER } from '../../../modules/local/shared/orthofinder/main'
include { IQTREE2     } from '../../../modules/local/shared/iqtree2/main'
include { CAFE5       } from '../../../modules/local/fungalflow/cafe5/main'

workflow COMPARATIVE_FUNGAL {
    take:
    ch_all_proteomes // channel: path("proteomes/*") -> Aggregated directory containing all target fasta files
    ch_gffs        // [ path(annotation.gff), ... ] — collected from all samples


main:
    ch_versions = Channel.empty()

   // Step 1 — gene family clustering
   ORTHOFINDER( ch_all_proteomes )
   ch_versions = ch_versions.mix( ORTHOFINDER.out.versions )

  // Step 2 — species tree
  IQTREE2( ORTHOFINDER.out.orthogroups )
  ch_versions = ch_versions.mix( IQTREE2.out.versions )

  // Step 3 — gene family evolution
  CAFE5( ORTHOFINDER.out.gene_counts, IQTREE2.out.tree )
  ch_versions = ch_versions.mix( CAFE5.out.versions )

  emit:
  orthogroups = ORTHOFINDER.out.orthogroups
  tree        = IQTREE2.out.tree
  cafe_results = CAFE5.out.results
  versions    = ch_versions
}