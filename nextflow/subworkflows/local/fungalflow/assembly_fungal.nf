
include { SPADES    } from '../../../modules/local/shared/spades/main'
include { FLYE      } from '../../../modules/nf-core/flye/main'
include { QUAST     } from '../../../modules/nf-core/quast/main'
include { BUSCO     } from '../../../modules/local/shared/busco/main'

workflow ASSEMBLY_FUNGAL {
    take:
    ch_shortreads  // channel: [ val(meta), [ path(R1), path(R2) ] ] or empty
    ch_longreads   // channel: [ val(meta), path(reads.fastq.gz) ]   or empty

    main:
    ch_versions       = Channel.empty()
    ch_final_assembly = Channel.empty()

// ── Mode 1: Short reads only — SPAdes ──────────────────────────────────
// SPAdes --isolate: optimised for single-strain fungal isolates
// Produces contigs.fasta — typical fungal assembly 50-500 contigs
    if ( ch_shortreads ) {
       def has_long_for_hybrid = ( ch_longreads != Channel.empty() )
       SPADES( ch_shortreads, ch_longreads )
       ch_final_assembly = SPADES.out.scaffolds
       ch_versions       = ch_versions.mix( SPADES.out.versions )

       log.info "INFO: SPAdes assembly complete"
    }
// ── Mode 2: Long reads only — Flye ─────────────────────────────────────
// Flye --nano-hq: for R10.4 ONT chemistry (high quality)
// Produces assembly.fasta — typically 10-50 contigs for fungal genomes
     else if ( ch_longreads ) {
          FLYE( ch_longreads )
          ch_final_assembly = FLYE.out.assembly
          ch_versions       = ch_versions.mix( FLYE.out.versions )
          log.info "INFO: Flye assembly complete"
     }
// ── Validate assembly has content ───────────────────────────────────────
      ch_final_assembly = ch_final_assembly
          .map { meta, fasta ->
              if ( !fasta || fasta.size() < 1000 ) {
              error "PIPELINE ERROR: Assembly output is empty or too small (${fasta?.size()} bytes)"
               }
          return [ meta, fasta ]
           }
// ── Assembly QC ─────────────────────────────────────────────────────────
// QUAST: N50, L50, contig count, total length
// BUSCO fungi_odb10: gene space completeness
// Expected: fungi_odb10 >90% for well-sequenced industrial fungi

QUAST(
ch_final_assembly,
[ [id:'no_ref'], [] ],
[ [id:'no_gff'], [] ]    // no GFF annotation yet
)
ch_versions = ch_versions.mix( QUAST.out.versions_quast )

BUSCO(
ch_final_assembly,
params.busco_mode ?: 'genome',
params.busco_lineage ?: 'fungi_odb10'
)
ch_versions = ch_versions.mix( BUSCO.out.versions )

emit:
assembly  = ch_final_assembly
quast_tsv = QUAST.out.tsv
busco_txt = BUSCO.out.short_txt
versions  = ch_versions

}