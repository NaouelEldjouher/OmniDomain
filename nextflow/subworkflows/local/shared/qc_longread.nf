// subworkflows/local/shared/qc_longread.nf

/*
 * Include the official nf-core modules we installed earlier
 */
include { FILTLONG } from '../../../modules/nf-core/filtlong/main'
include { NANOPLOT } from '../../../modules/nf-core/nanoplot/main'

workflow QC_LONGREAD {
    take:
    ch_raw_longreads // channel: [ val(meta), path(fastq) ]

    main:
    ch_versions = Channel.empty()

    // 1. Run Filtlong to drop low-quality bases and short reads
    // Filtlong takes a tuple of [ meta, fastq ] and an optional short-read reference (passed as [] here)
    FILTLONG (
        ch_raw_longreads,
        []
    )
    ch_filtered_reads = FILTLONG.out.reads
    ch_versions       = ch_versions.mix(FILTLONG.out.versions)

    // 2. Run NanoPlot on the clean, filtered reads to generate high-fidelity QC metrics
    NANOPLOT (
        ch_filtered_reads
    )
    ch_versions = ch_versions.mix(NANOPLOT.out.versions)

    emit:
    reads    = ch_filtered_reads // channel: [ val(meta), path(fastq) ]
    png      = NANOPLOT.out.png   // channel: [ val(meta), path(png_plots) ]
    html     = NANOPLOT.out.html  // channel: [ val(meta), path(html_report) ]
    versions = ch_versions        // channel: [ path(versions.yml) ]
}