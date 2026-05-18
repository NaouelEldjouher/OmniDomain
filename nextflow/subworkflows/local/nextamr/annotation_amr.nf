// subworkflows/local/nextamr/annotation_amr.nf

include { BAKTA         } from '../../../modules/local/bakta/main'
include { AMRFINDERPLUS } from '../../../modules/local/amrfinderplus/main'

workflow ANNOTATION_AMR {
    take:
    ch_polished_assembly // channel: [ val(meta), path(assembly.fasta) ]
    ch_bakta_db          // path: Path to the downloaded Bakta database
    ch_amrfinder_db      // path: Path to the downloaded NCBI AMR database

    main:
    ch_versions = Channel.empty()

    // 1. Run Bakta for rapid, standardized bacterial structural and functional annotation
    BAKTA ( ch_polished_assembly, ch_bakta_db )
    ch_versions = ch_versions.mix(BAKTA.out.versions)

    // 2. Run AMRFinderPlus on the assembly and Bakta proteins to detect resistance/virulence
    AMRFINDERPLUS ( 
        ch_polished_assembly, 
        BAKTA.out.proteins, 
        ch_amrfinder_db 
    )
    ch_versions = ch_versions.mix(AMRFINDERPLUS.out.versions)

    emit:
    gff      = BAKTA.out.gff         // channel: [ val(meta), path(*.gff3) ] Standard annotation
    gbk      = BAKTA.out.gbk         // channel: [ val(meta), path(*.gbff) ] GenBank format
    amr_tsv  = AMRFINDERPLUS.out.tsv // channel: [ val(meta), path(*.tsv) ] Resistance profiles
    versions = ch_versions           // channel: [ path(versions.yml) ]
}