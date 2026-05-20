include { BAKTA         } from '../../../modules/local/bakta/main'
include { AMRFINDERPLUS } from '../../../modules/local/amrfinderplus/main'

workflow ANNOTATION_AMR {
    take:
    ch_polished_assembly // channel: [ val(meta), path(assembly.fasta) ]
    ch_bakta_db          // path: Path to the downloaded Bakta database
    ch_amrfinder_db      // path: Path to the downloaded NCBI AMR database

    main:
    ch_versions = Channel.empty()

    // 1. Run Bakta
    BAKTA ( ch_polished_assembly, ch_bakta_db )
    
    ch_gff      = BAKTA.out.gff
    ch_gbk      = BAKTA.out.gff   // Standardized to the available .gff format output
    ch_versions = ch_versions.mix(BAKTA.out.versions)

    // 2. Run AMRFinderPlus passing exactly the TWO required inputs:
    // Input 1: The nucleotide assembly tuple channel
    // Input 2: The database directory path channel
    AMRFINDERPLUS ( 
        ch_polished_assembly, 
        ch_amrfinder_db 
    )
    
    // Use your exact named outputs from the module file
    ch_amr_tsv  = AMRFINDERPLUS.out.report
    ch_versions = ch_versions.mix(AMRFINDERPLUS.out.versions)

    emit:
    gff      = ch_gff      // channel: [ val(meta), path(*.gff3) ]
    gbk      = ch_gbk      // channel: [ val(meta), path(*.gff3) ]
    amr_tsv  = ch_amr_tsv  // channel: [ val(meta), path(*.tsv) ]
    versions = ch_versions // channel: [ path(versions.yml) ]
}