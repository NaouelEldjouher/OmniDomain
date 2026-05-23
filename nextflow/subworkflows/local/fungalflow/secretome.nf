// Secretome prediction — signal peptide detection for industrial enzyme discovery
// Tool: DeepSig v1.2.5 — open source, no license required
// Replaces: SignalP, Phobius, TMHMM, TargetP2 (all require academic licenses)
include { DEEPSIG } from '../../../modules/local/fungalflow/deepsig/main'

workflow SECRETOME {

    take:
    ch_proteins

    main:
    ch_versions = Channel.empty()

    DEEPSIG( ch_proteins )
    ch_versions = ch_versions.mix( DEEPSIG.out.versions )

    emit:
    secreted_proteins = DEEPSIG.out.secreted
    gff3              = DEEPSIG.out.results
    versions          = ch_versions

}
