// subworkflows/local/shared/qc_shortread.nf

/*
 * Include the official nf-core fastp module wrapper
 */
include { FASTP } from '../../../modules/nf-core/fastp/main'
workflow QC_SHORTREAD {
take:
ch_raw_shortreads

main:
ch_versions = Channel.empty()

// Add single_end: false so FASTP uses paired-end code path
// Add [] as empty adapter_fasta — part of the input tuple (nf-core fastp)
ch_fastp_input = ch_raw_shortreads
.map { meta, reads ->
def new_meta = [ *:meta, single_end: false ]
[ new_meta, reads, [] ]
}

FASTP(
ch_fastp_input,
false,
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