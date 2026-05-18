// subworkflows/local/shared/qc_shortread.nf

/*
 * Include the official nf-core fastp module wrapper
 */
include { FASTP } from '../../../modules/nf-core/fastp/main'

workflow QC_SHORTREAD {
    take:
    ch_raw_shortreads // channel: [ val(meta), path(reads) ] 
                      // Supports both single-end [read] or paired-end [read_1, read_2]

    main:
    ch_versions = Channel.empty()

    // Run FastP adapter trimming and quality filtering
    // Arguments: channel, adapter_fasta (none/[]), save_trimmed_fail (false), save_merged (false)
    FASTP (
        ch_raw_shortreads,
        [],
        false,
        false
    )

    ch_filtered_reads = FASTP.out.reads
    ch_versions       = ch_versions.mix(FASTP.out.versions)

    emit:
    reads    = ch_filtered_reads // channel: [ val(meta), path(trimmed_reads) ]
    json     = FASTP.out.json    // channel: [ val(meta), path(*.json) ] for dashboard parsing
    html     = FASTP.out.html    // channel: [ val(meta), path(*.html) ] for MultiQC
    versions = ch_versions       // channel: [ path(versions.yml) ]
}