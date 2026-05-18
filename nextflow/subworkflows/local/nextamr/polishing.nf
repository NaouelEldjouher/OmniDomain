// subworkflows/local/nextamr/polishing.nf

include { DNAAPLER } from '../../../modules/local/dnaapler/main'
include { MEDAKA   } from '../../../modules/local/medaka/main'
include { PYPOLCA  } from '../../../modules/local/pypolca/main'

workflow POLISHING {
    take:
    ch_assembly   // channel: [ val(meta), path(draft_assembly.fasta) ]
    ch_longreads  // channel: [ val(meta), path(long_reads.fastq) ]
    ch_shortreads // channel: [ val(meta), path(short_reads.fastq) ]

    main:
    ch_versions = Channel.empty()

    // 1. Reorient circular contigs to start at dnaA (standardizes bacterial genomes)
    DNAAPLER ( ch_assembly )
    ch_oriented_assembly = DNAAPLER.out.fasta
    ch_versions = ch_versions.mix(DNAAPLER.out.versions)

    // 2. Polish with Medaka (Neural network polishing for ONT long reads)
    // Note: If running short-read only, you would use a conditional bypass here
    MEDAKA ( ch_oriented_assembly, ch_longreads )
    ch_medaka_assembly = MEDAKA.out.polished_fasta
    ch_versions = ch_versions.mix(MEDAKA.out.versions)

    // 3. Polish with Pypolca (High-accuracy short-read polishing)
    PYPOLCA ( ch_medaka_assembly, ch_shortreads )
    ch_final_assembly = PYPOLCA.out.polished_fasta
    ch_versions = ch_versions.mix(PYPOLCA.out.versions)

    emit:
    polished_assembly = ch_final_assembly // channel: [ val(meta), path(*.fasta) ]
    versions          = ch_versions       // channel: [ path(versions.yml) ]
}