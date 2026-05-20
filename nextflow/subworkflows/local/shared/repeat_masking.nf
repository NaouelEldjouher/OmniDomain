// ============================================================================
// subworkflows/local/shared/repeat_masking.nf
// ============================================================================

include { REPEATMODELER } from '../../../modules/local/repeatmodeler/main'
include { REPEATMASKER  } from '../../../modules/local/repeatmasker/main'

workflow REPEAT_MASKING {
    take:
    ch_assembly // channel: [ val(meta), path(assembly.fasta) ]

    main:
    ch_versions = Channel.empty()

    // ── 1. REPEATMODELER ────────────────────────────────────────────────────
    // De novo repeat family discovery — builds organism-specific repeat library
    // Required before RepeatMasker for accurate soft-masking
    // Runtime: 2-8 hours depending on genome size
    REPEATMODELER( ch_assembly )
    ch_versions = ch_versions.mix( REPEATMODELER.out.versions )

    // ── 2. JOIN assembly + repeat library on meta ────────────────────────────
    // Creates: [ meta, path(assembly.fasta), path(*-families.fa) ]
    ch_repeatmasker_input = ch_assembly.join( REPEATMODELER.out.repeat_library )

    // ── 3. REPEATMASKER ─────────────────────────────────────────────────────
    // Soft-masks identified repeats using RepeatModeler library + DFam
    // -xsmall flag: lowercase soft-masking (preserves sequence, hides from predictors)
    // Nuclear plants: expect 40-85% masked; organelles: expect <5% masked
    REPEATMASKER( ch_repeatmasker_input )
    ch_versions = ch_versions.mix( REPEATMASKER.out.versions )

    emit:
    masked_fasta = REPEATMASKER.out.masked_fasta  // [ meta, path(*.masked.fa) ]
    report       = REPEATMASKER.out.summary_table // [ meta, path(*.tbl) ]
    versions     = ch_versions
}
