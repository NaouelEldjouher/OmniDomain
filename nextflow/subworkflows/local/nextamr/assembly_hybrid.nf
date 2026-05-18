// subworkflows/local/nextamr/assembly_hybrid.nf

include { UNICYCLER } from '../../../modules/local/unicycler/main'

workflow ASSEMBLY_HYBRID {
    take:
    ch_shortreads // channel: [ val(meta), path(fastq_1, fastq_2) ]
    ch_longreads  // channel: [ val(meta), path(fastq) ]

    main:
    ch_versions = Channel.empty()

    // Run Unicycler providing both read sets
    UNICYCLER ( ch_shortreads, ch_longreads )
    ch_versions = ch_versions.mix(UNICYCLER.out.versions)

    emit:
    assembly = UNICYCLER.out.gfa_or_fasta // channel: [ val(meta), path(*.fasta) ]
    versions = ch_versions                // channel: [ path(versions.yml) ]
}