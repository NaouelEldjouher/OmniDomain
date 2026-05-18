// subworkflows/local/plantflow/scaffolding.nf

include { YAHS   } from '../../../modules/local/yahs/main'
include { RAGTAG } from '../../../modules/local/ragtag/main'

workflow SCAFFOLDING {
    take:
    ch_assembly  // channel: [ val(meta), path(fasta) ]
    ch_hic_map   // channel: [ val(meta), path(hic_alignment.bam) ] (Optional)
    ch_reference // channel: [ val(meta), path(reference.fasta) ] (Optional)

    main:
    ch_versions = Channel.empty()
    ch_current_scaffolds = ch_assembly

    // 1. De novo Hi-C scaffolding (Builds massive pseudochromosomes)
    if ( ch_hic_map ) {
        YAHS ( ch_assembly, ch_hic_map )
        ch_current_scaffolds = YAHS.out.scaffolds
        ch_versions = ch_versions.mix(YAHS.out.versions)
    }

    // 2. Reference-guided scaffolding (Fills in gaps using a cousin species)
    if ( ch_reference ) {
        RAGTAG ( ch_current_scaffolds, ch_reference )
        ch_current_scaffolds = RAGTAG.out.scaffolds
        ch_versions = ch_versions.mix(RAGTAG.out.versions)
    }

    emit:
    scaffolds = ch_current_scaffolds // channel: [ val(meta), path(*.fasta) ]
    versions  = ch_versions
}