include { KRAKEN2 } from '../../../modules/local/metacflow/kraken2/main'
include { BRACKEN } from '../../../modules/local/metacflow/bracken/main'

workflow TAXONOMY {

    take:
    ch_reads     // [ val(meta), path(reads) ]
    kraken2_db   // path to Kraken2 database

    main:
    ch_versions = Channel.empty()

    KRAKEN2( ch_reads, kraken2_db )
    ch_versions = ch_versions.mix( KRAKEN2.out.versions )

    BRACKEN( KRAKEN2.out.report, kraken2_db )
    ch_versions = ch_versions.mix( BRACKEN.out.versions )

    emit:
    kraken2_report = KRAKEN2.out.report   // [ meta, txt ]
    bracken_report = BRACKEN.out.report   // [ meta, txt ]
    bracken_txt    = BRACKEN.out.txt      // [ meta, txt ]
    versions       = ch_versions
}
