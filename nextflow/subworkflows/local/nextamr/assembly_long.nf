include { FLYE } from '../../../modules/nf-core/flye/main'

workflow ASSEMBLY_LONG {
    take:
    ch_longreads // channel: [ val(meta), path(fastq) ]

    main:
    ch_versions = Channel.empty()

    // 1. Run Flye by passing BOTH required arguments: 
    // Argument 1: The input reads tuple channel
    // Argument 2: The sequencing mode string value (matching nf-core standards)
    FLYE ( ch_longreads, '--nano-hq' ) 

    // 2. Safely capture the multi-channel output using array indices
    ch_assembly = FLYE.out[0]
    ch_graph    = FLYE.out[1]
    ch_versions = ch_versions.mix(FLYE.out[4])

    emit:
    assembly = ch_assembly // channel: [ val(meta), path(*.fasta) ]
    graph    = ch_graph    // channel: [ val(meta), path(*.gfa) ]
    versions = ch_versions // channel: [ path(versions.yml) ]
}