include { SPADES } from '../../../modules/local/shared/spades/main'
include { FLYE   } from '../../../modules/local/shared/flye/main'
include { QUAST  } from '../../../modules/nf-core/quast/main'
// BUSCO disabled for local test — 200k read subset produces 9,958 contigs
// which exceeds local memory limits for miniprot_align step
// Re-enable on AWS with full dataset (27M reads, expected N50 ~100kb)
// include { BUSCO } from '../../../modules/local/shared/busco/main'
//include { BUSCO  } from '../../../modules/local/shared/busco/main'

workflow ASSEMBLY_FUNGAL {
take:
ch_shortreads  // [ val(meta), [path(R1), path(R2)] ] or empty
ch_longreads   // [ val(meta), path(reads.fastq.gz) ] or empty
has_short      // val Boolean — from main.nf
has_long       // val Boolean — from main.nf

main:
ch_versions       = Channel.empty()
ch_final_assembly = Channel.empty()

// ── Mode 1 + 3: SPAdes — short reads or hybrid ─────────────────────
if ( has_short ) {
log.info "INFO: SPAdes assembler selected"

ch_long_for_spades = has_long
? ch_longreads
: Channel.value( [ [id:'no_long'], [] ] )

SPADES( ch_shortreads, ch_long_for_spades )
ch_final_assembly = SPADES.out.scaffolds
ch_versions       = ch_versions.mix( SPADES.out.versions )
}

// ── Mode 2: Flye — long reads only ─────────────────────────────────
else if ( has_long ) {
     log.info "INFO: Flye assembler selected"
     FLYE( ch_longreads, '--nano-hq' )
     ch_final_assembly = FLYE.out.fasta
     ch_versions       = ch_versions.mix(FLYE.out.versions_flye)
}

// ── Validate ────────────────────────────────────────────────────────
ch_validated = ch_final_assembly
.map { meta, fasta ->
if ( !fasta ) {
error "Assembly file missing"
}
return [ meta, fasta ]
}

// ── Assembly QC ─────────────────────────────────────────────────────
QUAST(
ch_validated,
[ [id:'no_ref'], [] ],
[ [id:'no_gff'], [] ]
)


//BUSCO( ch_validated, 'genome', 'fungi_odb10' )
//ch_versions = ch_versions.mix( BUSCO.out.versions )

emit:
assembly  = ch_validated
quast_tsv = QUAST.out.tsv
busco_txt = Channel.empty()    // placeholder — BUSCO disabled for local test
versions  = ch_versions
}