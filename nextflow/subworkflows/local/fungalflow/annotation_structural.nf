
include { BRAKER3     } from '../../../modules/local/shared/braker3/main'
include { FUNANNOTATE } from '../../../modules/local/fungalflow/funannotate/main'

workflow ANNOTATION_STRUCTURAL {
    take:
    ch_masked_assembly // channel: [ val(meta), path(masked_genome.fa) ]
    ch_protein_hints   // channel: path(proteins.fa)
    ch_rnaseq_bam      // channel: [ val(meta), path(aligned_rna.bam) ]

    main:
    ch_versions = Channel.empty()
    ch_braker_gff = Channel.empty()


    // If no RNA-seq is provided, BRAKER3 is completely ignored by the graph builder.
    if ( params.rnaseq_bam ) {
        
        BRAKER3 (
            ch_masked_assembly,
            ch_protein_hints,
            ch_rnaseq_bam
        )
        ch_braker_gff = BRAKER3.out.gff3
        ch_versions   = ch_versions.mix(BRAKER3.out.versions)

    } else {
        // Safe Fallback: If BRAKER3 is bypassed, populate a clean mock structure [meta, []]
        // so that the downstream .join() with Funannotate still aligns perfectly.
        ch_braker_gff = ch_masked_assembly.map { meta, fasta -> [ meta, [] ] }
    }

    // 2. Unify, Clean, and Finalize Gene Names (FUNANNOTATE)
    // The .join() operator cleanly pairs up the assembly and the gff structure on the 'meta' key
    ch_funannotate_input = ch_masked_assembly.join(ch_braker_gff)

    FUNANNOTATE ( ch_funannotate_input )
    
    ch_final_gff3     = FUNANNOTATE.out.gff3
    ch_final_proteins = FUNANNOTATE.out.proteins
    ch_versions       = ch_versions.mix(FUNANNOTATE.out.versions)

    emit:
    gff3     = ch_final_gff3     // channel: [ val(meta), path(*.gff3) ]
    proteins = ch_final_proteins // channel: [ val(meta), path(*.proteins.fa) ]
    versions = ch_versions       // channel: [ path(versions.yml) ]
}