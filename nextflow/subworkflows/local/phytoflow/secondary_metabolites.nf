// ============================================================================
// subworkflows/local/plantflow/secondary_metabolites.nf
// ============================================================================

include { NLR_ANNOTATOR } from '../../../modules/local/phytoflow/nlr_annotator/main'

workflow SECONDARY_METABOLITES {
    take:
    ch_scaffolds  // channel: [ val(meta), path(masked_assembly.fasta) ]
    ch_gff        // channel: [ val(meta), path(annotation.gff3) ] — may be empty
    ch_nlr_jar    // channel: path(NLR-Annotator.jar)
    ch_nlr_mot    // channel: path(mot.txt)
    ch_nlr_store  // channel: path(store.txt)

    main:
    ch_versions = Channel.empty()

    // Filter to primary contig — HIFIASM emits both p_ctg and bp.p_ctg
    // After GFA_TO_FASTA this should already be a single FASTA
    // Keep filter as defensive check
    ch_primary = ch_scaffolds.map { meta, files ->
        def primary = files instanceof List
            ? files.find { !it.name.contains('.bp.') } ?: files.first()
            : files
        return [ meta, primary ]
    }

    // ── NLR-Annotator ────────────────────────────────────────────────────────
    // Disease resistance gene (NBS-LRR / R gene) detection
    // Sequence-based — no GFF annotation required
    // Biologically meaningful only on nuclear genomes
    // On organelle data: runs quickly, finds nothing, expected behaviour
    // JAR + motif files passed as channels — supports local paths and S3 URIs
    ch_nlr_input = ch_primary
        .combine( ch_nlr_jar )
        .combine( ch_nlr_mot )
        .combine( ch_nlr_store )
        .map { meta, fasta, jar, mot, store ->
            [ meta, fasta, jar, mot, store ]
        }

    NLR_ANNOTATOR( ch_nlr_input )
    ch_versions = ch_versions.mix( NLR_ANNOTATOR.out.versions )

    emit:
    nlr_txt  = NLR_ANNOTATOR.out.results  // [ meta, path(*.txt) ]
    versions = ch_versions
}