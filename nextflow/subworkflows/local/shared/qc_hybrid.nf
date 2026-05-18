// subworkflows/local/shared/qc_hybrid.nf

/*
 * Import your existing local shared subworkflows natively!
 */
include { QC_SHORTREAD } from './qc_shortread'
include { QC_LONGREAD  } from './qc_longread'

workflow QC_HYBRID {
    take:
    ch_raw_shortreads // channel: [ val(meta), path(short_reads) ]
    ch_raw_longreads  // channel: [ val(meta), path(long_reads) ]

    main:
    ch_versions = Channel.empty()

    // 1. Send short reads to your standard FastP subworkflow
    QC_SHORTREAD ( ch_raw_shortreads )
    
    // 2. Send long reads to your standard Filtlong + NanoPlot subworkflow
    QC_LONGREAD ( ch_raw_longreads )

    // 3. Mix the version history files from both subworkflow tracks
    ch_versions = ch_versions.mix(QC_SHORTREAD.out.versions)
    ch_versions = ch_versions.mix(QC_LONGREAD.out.versions)

    emit:
    short_reads = QC_SHORTREAD.out.reads // channel: [ val(meta), path(clean_short_reads) ]
    long_reads  = QC_LONGREAD.out.reads  // channel: [ val(meta), path(clean_long_reads) ]
    short_html  = QC_SHORTREAD.out.html  // channel: [ val(meta), path(fastp.html) ]
    long_html   = QC_LONGREAD.out.html   // channel: [ val(meta), path(nanoplot.html) ]
    versions    = ch_versions            // channel: [ path(versions.yml) ]
}