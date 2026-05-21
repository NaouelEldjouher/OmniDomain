// subworkflows/local/fungalflow/secondary_metabolites.nf

include { ANTISMASH } from '../../../modules/local/fungalflow/antismash/main'

workflow SECONDARY_METABOLITES {
take:
ch_assembly  // [ val(meta), path(assembly.fasta) ]
ch_gff       // [ val(meta), path(annotation.gff3) ]

main:
ch_versions = Channel.empty()

// antiSMASH — biosynthetic gene cluster detection
// Finds: PKS, NRPS, terpenes, RiPPs, siderophores
// Relevant for: industrial enzyme companies, natural product discovery
// Requires annotation GFF for full cluster context
ch_antismash_input = ch_assembly

ANTISMASH( ch_antismash_input )
ch_versions = ch_versions.mix( ANTISMASH.out.versions )

emit:
bgc_results = ANTISMASH.out.results  // [ meta, path(antismash_output/) ]
versions    = ch_versions
}