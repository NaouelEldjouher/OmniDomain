// subworkflows/local/shared/qc_shortread.nf

/*
 * Include the official nf-core fastp module wrapper
 */
include { FASTP } from '../../../modules/nf-core/fastp/main'

workflow QC_SHORTREAD {
    take:
    ch_raw_shortreads // channel: [ val(meta), path(reads) ] 

    main:
    ch_versions = Channel.empty()

    ch_fastp_inputs = ch_raw_shortreads.map { meta, reads -> [ meta, reads, [] ] }

    // Run FastP adapter trimming and quality filtering

    FASTP (
        ch_fastp_inputs,
        false,
        false,
        false
    )

    ch_filtered_reads = FASTP.out.reads
    
    // Safety check for versions channel property
    if (FASTP.out.versions) { ch_versions = ch_versions.mix(FASTP.out.versions) }

    emit:
    reads    = ch_filtered_reads 
    json     = FASTP.out.json    
    html     = FASTP.out.html    
    versions = ch_versions       
}