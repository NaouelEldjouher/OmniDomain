// subworkflows/local/plantflow/secondary_metabolites.nf

include { ANTISMASH     } from '../../../modules/local/antismash/main'
include { NLR_ANNOTATOR } from '../../../modules/local/nlr_annotator/main'

workflow SECONDARY_METABOLITES {
    take:
    ch_scaffolds // channel: [ val(meta), path(assembly.fasta) ]
    ch_gff       // channel: [ val(meta), path(annotation.gff3) ]

    main:
    ch_versions = Channel.empty()

    // 1. antiSMASH Plant Mode: Discover secondary metabolite clusters (BGCs)
    ANTISMASH ( ch_scaffolds, ch_gff )
    ch_versions = ch_versions.mix(ANTISMASH.out.versions)

    // 2. NLR-Annotator: Identify disease resistance gene loci directly from genomic DNA
    NLR_ANNOTATOR ( ch_scaffolds )
    ch_versions = ch_versions.mix(NLR_ANNOTATOR.out.versions)

    emit:
    antismash_dir = ANTISMASH.out.results     // channel: [ val(meta), path(antismash_output/) ]
    nlr_txt       = NLR_ANNOTATOR.out.results // channel: [ val(meta), path(*.txt) ]
    versions      = ch_versions               // channel: [ path(versions.yml) ]
}