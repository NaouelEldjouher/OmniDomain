include { SPADES } from '../../../modules/local/shared/spades/main'
include { FLYE   } from '../../../modules/nf-core/flye/main'
include { QUAST  } from '../../../modules/nf-core/quast/main'

workflow ASSEMBLY_FUNGAL {

    take:
    ch_shortreads
    ch_longreads
    has_short
    has_long

    main:
    ch_versions       = Channel.empty()
    ch_final_assembly = Channel.empty()

    if ( has_short ) {
        log.info "INFO: SPAdes assembler selected"
        def ch_long_for_spades = has_long
            ? ch_longreads
            : Channel.value( [ [id:'no_long'], [] ] )
        SPADES( ch_shortreads, ch_long_for_spades )
        ch_final_assembly = SPADES.out.scaffolds
        ch_versions       = ch_versions.mix( SPADES.out.versions )
    } else if ( has_long ) {
        log.info "INFO: Flye assembler selected"
        FLYE( ch_longreads, '--nano-hq' )
        ch_final_assembly = FLYE.out.fasta
        ch_versions       = ch_versions.mix( FLYE.out.versions_flye )
    }

    def ch_validated = ch_final_assembly
        .map { meta, fasta ->
            if ( !fasta ) { error "Assembly file missing" }
            return [ meta, fasta ]
        }

    QUAST(
        ch_validated,
        [ [id:'no_ref'], [] ],
        [ [id:'no_gff'], [] ]
    )

    emit:
    assembly  = ch_validated
    quast_tsv = QUAST.out.tsv
    busco_txt = Channel.empty()
    versions  = ch_versions

}
