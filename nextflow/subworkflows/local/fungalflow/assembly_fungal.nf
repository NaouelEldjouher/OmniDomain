include { HIFIASM   } from '../../../modules/nf-core/hifiasm/main'

include { QUAST     } from '../../../modules/nf-core/quast/main'
include { BUSCO     } from '../../../modules/local/shared/busco/main'

workflow ASSEMBLY_FUNGAL {
    take:
    ch_longreads  // channel: [ val(meta), path(fastq/fasta) ]
    ch_shortreads // channel: [ val(meta), path(fastq) ]
    ch_busco_db   // path

    main:
    ch_versions = Channel.empty()
    ch_final_assembly = Channel.empty()

    if ( params.longreads ) {

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


    // 2. Structural Validation Phase (Run QUAST metrics)

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
}