// subworkflows/local/nextamr/assembly_hybrid.nf

include { SPADES } from '../../../modules/local/spades/main'

workflow ASSEMBLY_HYBRID {
    take:
    ch_shortreads // channel: [ val(meta), path(fastq_1, fastq_2) ]
    ch_longreads  // channel: [ val(meta), path(fastq) ]

    main:
    ch_versions = Channel.empty()

    // Run SPAdes in hybrid metagenomic co-assembly mode
    // We pass both short and long channels into metaSPAdes
    SPADES ( ch_shortreads, ch_longreads )
    
    ch_assembly = SPADES.out.scaffolds
    ch_versions = ch_versions.mix(SPADES.out.versions)

    emit:
    assembly = ch_assembly // channel: [ val(meta), path(*.fasta) ]
    versions = ch_versions // channel: [ path(versions.yml) ]
}