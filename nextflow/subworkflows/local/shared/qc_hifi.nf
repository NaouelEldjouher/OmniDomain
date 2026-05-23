// subworkflows/local/shared/qc_hifi.nf
// Description: Quality control subworkflow specifically tailored for PacBio HiFi reads
include { HIFIADAPTERFILT } from '../../../modules/local/phytoflow/hifiadapterfilt/main'
include { SEQKIT_STATS    } from '../../../modules/local/shared/seqkit_stats/main'

workflow QC_HIFI {
    take:
    ch_reads  // channel: [ val(meta), path(hifi.fastq.gz) ]

    main:
    ch_versions = Channel.empty()

    // ── HiFiAdapterFilt ──────────────────────────────────────────────────────
 
    HIFIADAPTERFILT( ch_reads )
    ch_versions = ch_versions.mix( HIFIADAPTERFILT.out.versions )

    // ── seqkit stats ─────────────────────────────────────────────────────────
    SEQKIT_STATS( HIFIADAPTERFILT.out.reads )
    ch_versions = ch_versions.mix( SEQKIT_STATS.out.versions )

    emit:
    reads    = HIFIADAPTERFILT.out.reads   // clean HiFi reads → Hifiasm
    stats    = SEQKIT_STATS.out.stats      // QC stats → MultiQC
    versions = ch_versions
}