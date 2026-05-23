include { ANTISMASH } from '../../../modules/local/fungalflow/antismash/main'

workflow SECONDARY_METABOLITES {

    take:
    ch_assembly
    ch_gff

    main:
    ch_versions = Channel.empty()

    ANTISMASH( ch_assembly )
    ch_versions = ch_versions.mix( ANTISMASH.out.versions )

    emit:
    results  = ANTISMASH.out.results
    versions = ch_versions

}
