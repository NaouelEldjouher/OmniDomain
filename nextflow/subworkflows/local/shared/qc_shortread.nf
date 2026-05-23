include { FASTP } from '../../../modules/local/shared/fastp/main'

workflow QC_SHORTREAD {

    take:
    ch_raw_shortreads

    main:
    ch_versions = Channel.empty()

    def ch_fastp_input = ch_raw_shortreads
        .map { meta, reads ->
            def new_meta = [ *:meta, single_end: false ]
            [ new_meta, reads, [] ]
        }

    FASTP( ch_fastp_input, false, false, false )
    ch_versions = ch_versions.mix( FASTP.out.versions )

    emit:
    reads    = FASTP.out.reads
    json     = FASTP.out.json
    html     = FASTP.out.html
    versions = ch_versions

}
