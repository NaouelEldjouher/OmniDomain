// subworkflows/local/metacflow/assembly_short.nf

include { MEGAHIT } from '../../../modules/local/metacflow/megahit/main'

workflow ASSEMBLY_SHORT {
    take:
    ch_shortreads // channel: [ val(meta), path(fastq_1, fastq_2) ]

    main:
    ch_versions = Channel.empty()

    // Run MEGAHIT for highly optimized short-read metagenomic co-assembly
    MEGAHIT ( ch_shortreads )
    
    ch_assembly = MEGAHIT.out.contigs
    ch_versions = ch_versions.mix(MEGAHIT.out.versions)

    emit:
    assembly = ch_assembly // channel: [ val(meta), path(*.fasta) ]
    versions = ch_versions // channel: [ path(versions.yml) ]
}