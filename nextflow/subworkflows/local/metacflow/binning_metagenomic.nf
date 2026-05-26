// subworkflows/local/metacflow/binning_metagenomic.nf

// Keep your working local alignment tools
include { MINIMAP2_ALIGN } from '../../../modules/local/shared/minimap2/main'
include { JGI_SUMMARIZE_DEPTH } from '../../../modules/local/metacflow/jgi_depth/main'

// Swap your binning engines to your newly added nf-core folders!
include { METABAT2_METABAT2 as METABAT2 } from '../../../modules/nf-core/metabat2/metabat2/main'
include { CHECKM2_PREDICT   as CHECKM2   } from '../../../modules/nf-core/checkm2/predict/main'

workflow BINNING_METAGENOMIC {
    take:
    ch_raw_assembly  // channel: [ val(meta), path(co_assembly.fasta) ]
    ch_mapping_reads // channel: [ val(meta), path(reads) ]
    ch_checkm2_db    // channel: [ val(meta_db), path(checkm2_db_file) ]

    main:
    ch_versions = Channel.empty()

    // 1. Map raw reads back to the co-assembly to determine coverage abundance
    ch_minimap_inputs = ch_mapping_reads.join(ch_raw_assembly)
    
    MINIMAP2_ALIGN ( ch_minimap_inputs )
    
    // FIXED: Keep the complete [meta, bam, bai] tuple intact
    ch_versions  = ch_versions.mix(MINIMAP2_ALIGN.out.versions)

    // 2. Calculate contig depth profiles from the BAM file
    // FIXED: Passing the complete 3-element tuple that matches the input signature
    JGI_SUMMARIZE_DEPTH ( MINIMAP2_ALIGN.out.sam )
    ch_depth    = JGI_SUMMARIZE_DEPTH.out.depth
    ch_versions = ch_versions.mix( JGI_SUMMARIZE_DEPTH.out.versions )

    // ==============================================================================
    // 3. Join fasta and depth into a single multi-file channel block
    // ==============================================================================
    ch_metabat_inputs = ch_raw_assembly.join(ch_depth)
    
    METABAT2 ( ch_metabat_inputs )
    
    ch_raw_bins = METABAT2.out.fasta 
    if (METABAT2.out.versions) { ch_versions = ch_versions.mix(METABAT2.out.versions) }

    // ==============================================================================
    // 4. Pass the generated bins safely to CheckM2
    // ==============================================================================
    CHECKM2 ( ch_raw_bins, ch_checkm2_db )
    
    ch_filtered_mags = CHECKM2.out.checkm2_tsv 
    if (CHECKM2.out.versions) { ch_versions = ch_versions.mix(CHECKM2.out.versions) }

    emit:
    filtered_mags = ch_filtered_mags // Handed off directly to ANNOTATION_AMR
    versions      = ch_versions      // System-wide version tracking
}