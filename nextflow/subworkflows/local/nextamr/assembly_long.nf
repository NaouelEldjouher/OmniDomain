// subworkflows/local/nextamr/assembly_long.nf

include { FLYE } from '../../../modules/nf-core/flye/main'

workflow ASSEMBLY_LONG {
    take:
    ch_longreads // channel: [ val(meta), path(fastq) ]

    main:
    ch_versions = Channel.empty()

    // Run Flye. (Assuming task.ext.args in nextflow.config specifies --nano-hq or --pacbio-hifi)
    FLYE ( ch_longreads, "--nano-hq" ) 
    ch_versions = ch_versions.mix(FLYE.out.versions)

    emit:
    assembly = FLYE.out.fasta // channel: [ val(meta), path(*.fasta) ]
    graph    = FLYE.out.gfa   // channel: [ val(meta), path(*.gfa) ]
    versions = ch_versions    // channel: [ path(versions.yml) ]
}