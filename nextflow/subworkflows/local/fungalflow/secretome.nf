// subworkflows/local/fungalflow/secretome.nf

include { PHOBIUS } from '../../../modules/local/fungalflow/phobius/main'

workflow SECRETOME {
take:
ch_proteins // channel: [ val(meta), path(proteins.fasta) ]

main:
ch_versions = Channel.empty()

// Phobius: signal peptide + transmembrane topology prediction
// Public container — no license required
// Replaces SignalP (academic license, no public container)
// Output: proteins predicted to be secreted via classical pathway
PHOBIUS( ch_proteins )
ch_versions = ch_versions.mix( PHOBIUS.out.versions )

emit:
secreted_proteins = PHOBIUS.out.results  // [ meta, path(*.phobius.txt) ]
versions          = ch_versions
}