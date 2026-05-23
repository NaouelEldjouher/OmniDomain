#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { QC_SHORTREAD          } from '../subworkflows/local/shared/qc_shortread'
include { QC_LONGREAD           } from '../subworkflows/local/shared/qc_longread'
include { REPEAT_MASKING        } from '../subworkflows/local/shared/repeat_masking'
include { ASSEMBLY_FUNGAL       } from '../subworkflows/local/fungalflow/assembly_fungal'
include { ANNOTATION_STRUCTURAL } from '../subworkflows/local/fungalflow/annotation_structural'
include { ANNOTATION_FUNCTIONAL } from '../subworkflows/local/fungalflow/annotation_functional'
include { SECRETOME             } from '../subworkflows/local/fungalflow/secretome'
include { SECONDARY_METABOLITES } from '../subworkflows/local/fungalflow/secondary_metabolites'
include { COMPARATIVE_FUNGAL    } from '../subworkflows/local/fungalflow/comparative_fungal'

workflow {

    def has_short  = (params.shortreads || params.shortreads_r1) ? true : false
    def has_long   = params.longreads  ? true : false
    def has_hybrid = has_short && has_long

    if      ( has_hybrid ) { log.info ">>> MODE: Hybrid" }
    else if ( has_short  ) { log.info ">>> MODE: Short reads" }
    else if ( has_long   ) { log.info ">>> MODE: Long reads" }
    else                   { error "ERROR: provide --shortreads and/or --longreads" }

    def sample_id = params.sample_id ?: 'sample'
    log.info ">>> sample_id : ${sample_id}"

    def ch_shortreads = has_short
        ? ( params.shortreads_r1
            ? Channel.of( [ [id: params.sample_id ?: 'sample'],
                            [ file(params.shortreads_r1, checkIfExists: true),
                              file(params.shortreads_r2, checkIfExists: true) ] ] )
            : Channel.fromFilePairs( params.shortreads, checkIfExists: true )
                .map { id, reads -> [ [id: id], reads ] } )
        : Channel.empty()

    def ch_longreads = has_long
        ? Channel.fromPath( params.longreads, checkIfExists: true )
            .map { f -> [ [id: f.simpleName], f ] }
        : Channel.empty()

    def ch_rnaseq = params.rnaseq_bam
        ? Channel.fromPath( params.rnaseq_bam, checkIfExists: true )
            .map { f -> [ [id: 'rna_evidence'], f ] }
        : Channel.of( [ [id: 'rna_empty'], [] ] )

    def ch_protein_hints = params.protein_hints
        ? Channel.fromPath( params.protein_hints, checkIfExists: true )
            .map { f -> [ [id: 'prot_hints'], f ] }
        : Channel.of( [ [id: 'prot_empty'], [] ] )

    QC_SHORTREAD( ch_shortreads )
    QC_LONGREAD( ch_longreads )

    def ch_qc_short = has_short ? QC_SHORTREAD.out.reads : Channel.empty()
    def ch_qc_long  = has_long  ? QC_LONGREAD.out.reads  : Channel.empty()

    ASSEMBLY_FUNGAL( ch_qc_short, ch_qc_long, has_short, has_long )

    REPEAT_MASKING( ASSEMBLY_FUNGAL.out.assembly )

    ANNOTATION_STRUCTURAL(
        REPEAT_MASKING.out.masked_fasta,
        ch_protein_hints,
        ch_rnaseq
    )

    SECONDARY_METABOLITES(
        REPEAT_MASKING.out.masked_fasta,
        ANNOTATION_STRUCTURAL.out.gff
    )

    ANNOTATION_FUNCTIONAL( ANNOTATION_STRUCTURAL.out.proteins )

    SECRETOME( ANNOTATION_STRUCTURAL.out.proteins )

    if ( params.run_comparative ) {
        def ch_proteomes = ANNOTATION_STRUCTURAL.out.proteins
            .map { meta, fasta -> fasta }
            .collect()
        def ch_gffs = ANNOTATION_STRUCTURAL.out.gff
            .map { meta, gff -> gff }
            .collect()
        COMPARATIVE_FUNGAL( ch_proteomes, ch_gffs )
    } else {
        log.info "INFO: Comparative genomics skipped"
    }

}
