include { FASTP } from '../../../modules/local/shared/fastp/main'

workflow QC_SHORTREAD {

    take:
    ch_raw_shortreads

    main:
    ch_versions = Channel.empty()

    FASTP(
        ch_raw_shortreads,
        [],
        false,
        false
    )
    ch_versions = ch_versions.mix( FASTP.out.versions )

    emit:
    reads    = FASTP.out.reads
    json     = FASTP.out.json
    html     = FASTP.out.html
    versions = ch_versions

}
