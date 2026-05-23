// subworkflows/local/fungalflow/secretome.nf
// Secretome prediction — signal peptide detection for industrial enzyme discovery
//
// Tool: DeepSig v1.2.5 (Savojardo et al. 2018, Bioinformatics)
// Container: bolognabiocomp/deepsig — open source, no license required
// Mode: -k euk (eukaryote mode — correct for all fungi)
//
// Replaces standard tools (all licensed, no public containers):
//   SignalP  — DTU academic license
//   Phobius  — SBC Stockholm academic license
//   TMHMM    — DTU academic license
//   TargetP2 — DTU academic license
//
// Note: DeepSig predicts signal peptides only (classical secretion pathway)
// It does not predict TM topology. For full secretome pipeline with TM filtering,
// v2.0 plan: mount SignalP + Phobius into interpro/interproscan after free
// academic registration at services.healthtech.dtu.dk
include { DEEPSIG } from '../../../modules/local/fungalflow/deepsig/main'
workflow SECRETOME {
    take:
ch_proteins // channel: [ val(meta), path(proteins.fasta) ]
    main:
ch_versions = Channel.empty()

// DeepSig — deep learning signal peptide predictor
// Open source, no license, actively maintained (v1.2.5 Jan 2025)
// Output: GFF3 with Signal peptide / Chain annotations per protein
// Secreted proteins: annotated as "Signal peptide"
DEEPSIG( ch_proteins )
ch_versions = ch_versions.mix( DEEPSIG.out.versions )

    emit:
secreted_proteins = DEEPSIG.out.secreted  // [ meta, path(*.secreted.faa) ]
gff3              = DEEPSIG.out.results   // [ meta, path(*.deepsig.gff3) ]
versions          = ch_versions
}
