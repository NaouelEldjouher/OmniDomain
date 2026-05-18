// subworkflows/local/nextamr/assembly_short.nf

include { UNICYCLER } from '../../../modules/local/unicycler/main'

workflow ASSEMBLY_SHORT {
    take:
    ch_shortreads // channel: [ val(meta), path(fastq_1, fastq_2) ]

    main:
    ch_versions = Channel.empty()

    // Run Unicycler in short-read-only mode (pass empty array for long reads)
    UNICYCLER ( ch_shortreads, [] )
    ch_versions = ch_versions.mix(UNICYCLER.out.versions)

    emit:
    assembly = UNICYCLER.out.gfa_or_fasta // channel: [ val(meta), path(*.fasta) ]
    versions = ch_versions                // channel: [ path(versions.yml) ]
}