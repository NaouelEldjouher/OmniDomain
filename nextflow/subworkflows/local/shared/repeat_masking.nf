// subworkflows/local/shared/repeat_masking.nf

/*
 * Include your newly written custom local module wrappers
 */
include { REPEATMODELER } from '../../../modules/local/repeatmodeler/main'
include {  REPEATMASKER    } from '../../../modules/local/repeatmasker/main'

workflow REPEAT_MASKING {
    take:
    ch_assembly // channel: [ val(meta), path(draft_assembly.fa) ]

    main:
    ch_versions = Channel.empty()

    // 1. Generate custom, organism-specific repeat library definitions
    REPEATMODELER ( ch_assembly )
    ch_repeat_lib = REPEATMODELER.out.repeat_library
    ch_versions   = ch_versions.mix(REPEATMODELER.out.versions)

    // 2. Apply soft-masking configurations onto the input draft assemblies
    REPEATMASKER ( 
        ch_assembly,
        ch_repeat_lib
    )
    ch_versions = ch_versions.mix(REPEATMASKER.out.versions)

    emit:
    masked_fasta =  REPEATMASKER.out.masked_fasta // channel: [ val(meta), path(*.masked.fa) ]
    report       =  REPEATMASKER.out.report       // channel: [ val(meta), path(*.tbl) ]
    versions     = ch_versions                 // channel: [ path(versions.yml) ]
}