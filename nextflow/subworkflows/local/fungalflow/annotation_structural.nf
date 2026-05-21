// subworkflows/local/fungalflow/annotation_structural.nf

include { BRAKER3     } from '../../../modules/local/shared/braker3/main'
include { FUNANNOTATE } from '../../../modules/local/fungalflow/funannotate/main'


workflow ANNOTATION_STRUCTURAL {
take:
ch_masked_assembly  // [ val(meta), path(masked.fa) ]
ch_protein_hints    // [ val(meta), path(proteins.fa) ] or empty
ch_rnaseq_bam       // [ val(meta), path(rna.bam) ]    or empty

main:
ch_versions       = Channel.empty()
ch_annotation_gff = Channel.empty()
ch_proteins       = Channel.empty()

// annotation_structural.nf — correct v1.0 design
// Short reads / hybrid → Funannotate (nextgenusfs/funannotate:latest)
// Long reads only      → BRAKER3

if ( !params.longreads || params.shortreads ) {
log.info "INFO: Funannotate — short/hybrid read mode"
FUNANNOTATE( ch_masked_assembly, ch_protein_hints, ch_rnaseq_bam )
ch_annotation_gff = FUNANNOTATE.out.gff3
ch_proteins       = FUNANNOTATE.out.proteins
ch_versions       = ch_versions.mix( FUNANNOTATE.out.versions )

} else if ( params.longreads && !params.shortreads ) {
log.info "INFO: BRAKER3 — long read only mode"
BRAKER3( ch_masked_assembly, ch_protein_hints )
ch_annotation_gff = BRAKER3.out.gff
ch_proteins       = BRAKER3.out.proteins
ch_versions       = ch_versions.mix( BRAKER3.out.versions )
}


emit:
gff      = ch_annotation_gff  // [ meta, path(*.gff3 or *.gtf) ]
proteins = ch_proteins         // [ meta, path(*.proteins.faa) ]
versions = ch_versions
}