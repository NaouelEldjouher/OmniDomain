include { HIFIASM   } from '../../../modules/nf-core/hifiasm/main'
include { UNICYCLER } from '../../../modules/local/unicycler/main'
include { QUAST     } from '../../../modules/nf-core/quast/main'
include { BUSCO     } from '../../../modules/local/busco/main'

workflow ASSEMBLY_FUNGAL {
    take:
    ch_longreads  // channel: [ val(meta), path(fastq/fasta) ]
    ch_shortreads // channel: [ val(meta), path(fastq) ]
    ch_busco_db   // path

    main:
    ch_versions = Channel.empty()
    ch_final_assembly = Channel.empty()

    if ( params.longreads ) {
        // Explicitly provide a 3-element tuple structure to match [meta, long_reads, ul_reads]
        ch_hifiasm_input = ch_longreads.map { meta, reads -> [ meta, reads, [] ] }

        // Supply structured tuple fallbacks to prevent the nf-core unpacker from looking up null paths
        ch_trio_mock = [ [id:'trio_mock'], [], [] ]
        ch_hic_mock  = [ [id:'hic_mock'], [], [] ]
        ch_bin_mock  = [ [id:'bin_mock'], [] ]

        HIFIASM ( 
            ch_hifiasm_input, 
            ch_trio_mock, 
            ch_hic_mock, 
            ch_bin_mock 
        )
        
        ch_final_assembly = HIFIASM.out.primary_contigs
        ch_versions       = ch_versions.mix(HIFIASM.out.versions_hifiasm)

    } else if ( params.shortreads ) {
        ch_unicycler_input = ch_shortreads.map { meta, reads -> [ meta, reads, [] ] }

        UNICYCLER ( ch_unicycler_input )
        
        ch_final_assembly = UNICYCLER.out.scaf
        ch_versions       = ch_versions.mix(UNICYCLER.out.versions)
    }

    // 2. Structural Validation Phase (Run QUAST metrics)
    // FIXED: Replaced raw empty lists with valid tuple mock structures to pass validation
    ch_quast_gff_mock  = [ [id:'quast_gff_mock'], [] ]
    ch_quast_ref_mock  = [ [id:'quast_ref_mock'], [] ]

    QUAST ( ch_final_assembly, ch_quast_gff_mock, ch_quast_ref_mock )
    
    ch_quast_version = QUAST.out?.versions_quast ?: QUAST.out?.versions ?: Channel.empty()
    ch_versions      = ch_versions.mix(ch_quast_version)

    // 3. Biological Completeness Phase (Run BUSCO gene tracking)
    BUSCO ( ch_final_assembly, 'genome', 'fungi_odb10' )
    ch_versions = ch_versions.mix(BUSCO.out.versions)

    emit:
    assembly  = ch_final_assembly
    quast_tsv = QUAST.out.tsv
    busco_txt = BUSCO.out.short_txt
    versions  = ch_versions
}