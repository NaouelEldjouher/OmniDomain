// subworkflows/local/plantflow/annotation_structural.nf

include { HELIXER } from '../../../modules/local/helixer/main'
include { MAKER   } from '../../../modules/local/maker/main'

workflow ANNOTATION_STRUCTURAL {
    take:
    ch_scaffolds     // channel: [ val(meta), path(chromosome.fasta) ]
    ch_transcriptome // channel: [ val(meta), path(rna_evidence.fasta) ]
    ch_proteins      // channel: [ val(meta), path(protein_evidence.fasta) ]

    main:
    ch_versions = Channel.empty()

    // 1. Helixer: AI-driven ab initio prediction (Fast, requires GPUs)
    HELIXER ( ch_scaffolds )
    ch_versions = ch_versions.mix(HELIXER.out.versions)

    // 2. MAKER: Highly accurate evidence-driven prediction (Slow, highly parallel)
    MAKER ( ch_scaffolds, ch_transcriptome, ch_proteins )
    ch_versions = ch_versions.mix(MAKER.out.versions)

    emit:
    helixer_gff = HELIXER.out.gff // channel: [ val(meta), path(*.gff3) ]
    maker_gff   = MAKER.out.gff   // channel: [ val(meta), path(*.gff) ]
    versions    = ch_versions
}