// subworkflows/local/fungalflow/annotation_structural.nf

/*
 * Include your custom eukaryotic annotation wrappers from modules/local/
 */
include { BRAKER3     } from '../../../modules/local/braker3/main'
include { FUNANNOTATE } from '../../../modules/local/funannotate/main'

workflow ANNOTATION_STRUCTURAL {
    take:
    ch_masked_assembly // channel: [ val(meta), path(masked_genome.fa) ]
    ch_protein_hints   // path: path to a clean protein hints database (e.g., OrthoDB)
    ch_rnaseq_bam      // channel: [ val(meta), path(aligned_rna.bam) ] (Optional, pass [] if none)

    main:
    ch_versions = Channel.empty()

    // 1. Run BRAKER3 using state-of-the-art RNA-seq or Protein hint matrices
    BRAKER3 (
        ch_masked_assembly,
        ch_protein_hints,
        ch_rnaseq_bam
    )
    ch_braker_gff = BRAKER3.out.gff
    ch_versions   = ch_versions.mix(BRAKER3.out.versions)

    // 2. Run Funannotate Predict to clean, unify, and finalize fungal gene structural names
    FUNANNOTATE (
        ch_masked_assembly,
        ch_braker_gff
    )
    ch_final_gff3 = FUNANNOTATE.out.gff3
    ch_final_proteins = FUNANNOTATE.out.proteins
    ch_versions   = ch_versions.mix(FUNANNOTATE.out.versions)

    emit:
    gff3     = ch_final_gff3     // channel: [ val(meta), path(*.gff3) ] Standard annotation layout
    proteins = ch_final_proteins // channel: [ val(meta), path(*.proteins.fa) ] Fasta sequences for functional scaling
    versions = ch_versions       // channel: [ path(versions.yml) ]
}