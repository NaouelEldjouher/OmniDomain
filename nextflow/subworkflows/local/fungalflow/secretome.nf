// subworkflows/local/fungalflow/secretome.nf

/*
 * Include the local SignalP process module
 */
include { SIGNALP } from '../../../modules/local/signalp/main'

workflow SECRETOME {
    take:
    ch_proteins // channel: [ val(meta), path(proteins.fasta) ]

    main:
    ch_versions = Channel.empty()

    // Run SignalP to detect signal peptides and cleavage sites
    SIGNALP ( ch_proteins )
    
    ch_secreted_fasta = SIGNALP.out.summary_fasta
    ch_versions       = ch_versions.mix(SIGNALP.out.versions)

    emit:
    secreted_proteins = ch_secreted_fasta // channel: [ val(meta), path(*_summary.fasta) ]
    versions          = ch_versions       // channel: [ path(versions.yml) ]
}