nextflow.enable.dsl = 2

/*
 * 1. IMPORT SHARED CORE SUBWORKFLOWS
 */
include { QC_SHORTREAD } from '../subworkflows/local/shared/qc_shortread'
include { QC_LONGREAD  } from '../subworkflows/local/shared/qc_longread'
include { QC_HYBRID    } from '../subworkflows/local/shared/qc_hybrid'

/*
 * 2. IMPORT METAGENOMIC-SPECIFIC SUBWORKFLOWS
 */
include { ASSEMBLY_SHORT      } from '../subworkflows/local/nextamr/assembly_short'
include { ASSEMBLY_LONG       } from '../subworkflows/local/nextamr/assembly_long'
include { ASSEMBLY_HYBRID     } from '../subworkflows/local/nextamr/assembly_hybrid'
include { BINNING_METAGENOMIC } from '../subworkflows/local/nextamr/binning_metagenomic'
include { ANNOTATION_AMR      } from '../subworkflows/local/nextamr/annotation_amr'

/*
 * 3. MAIN WORKFLOW EXECUTION BLOCK
 */
workflow {
    // Check mandatory databases early to fail-fast if something is missing
    if (!params.checkm2_db)    { error "PARAMETER ERROR: Please supply the CheckM2 database path using --checkm2_db" }
    if (!params.bakta_db)      { error "PARAMETER ERROR: Please supply the Bakta database path using --bakta_db" }
    if (!params.amrfinder_db)  { error "PARAMETER ERROR: Please supply the AMRFinderPlus database path using --amrfinder_db" }

    // A. Parse Inputs into Nextflow Channels
    ch_shortreads = params.reads ? Channel.fromFilePairs(params.reads, checkIfExists: true).map { id, reads -> [ [id: id, single_end: false], reads ] } : Channel.empty()
    ch_longreads  = params.longreads ? Channel.fromPath(params.longreads, checkIfExists: true).map { file -> [ [id: file.baseName, single_end: true], file ] } : Channel.empty()
    
    // NEW: Parse CheckM2 Database File into a usable channel
    ch_checkm2_db = Channel.fromPath(params.checkm2_db, checkIfExists: true).map { file -> [ [id: 'checkm2_db'], file ] }.collect()

    ch_raw_assembly = Channel.empty()
    ch_mapping_reads = Channel.empty()

    // B. Core Routing Logic for Metagenomic Co-Assembly
    if (params.reads && params.longreads) {
        // --- HYBRID METAGENOMIC PATH ---
        QC_HYBRID ( ch_shortreads, ch_longreads )
        ASSEMBLY_HYBRID ( QC_HYBRID.out.short_reads, QC_HYBRID.out.long_reads )
        ch_raw_assembly  = ASSEMBLY_HYBRID.out.assembly
        ch_mapping_reads = QC_HYBRID.out.short_reads // Short reads used for abundance binning maps

    } else if (params.reads && !params.longreads) {
        // --- SHORT-READ ONLY METAGENOMIC PATH ---
        QC_SHORTREAD ( ch_shortreads )
        ASSEMBLY_SHORT ( QC_SHORTREAD.out.reads )
        ch_raw_assembly  = ASSEMBLY_SHORT.out.assembly
        ch_mapping_reads = QC_SHORTREAD.out.reads

    } else if (!params.reads && params.longreads) {
        // --- LONG-READ ONLY METAGENOMIC PATH ---
        QC_LONGREAD ( ch_longreads )
        ASSEMBLY_LONG ( QC_LONGREAD.out.reads )
        ch_raw_assembly  = ASSEMBLY_LONG.out.assembly
        ch_mapping_reads = QC_LONGREAD.out.reads

    } else {
        error "METAGENOMIC ERROR: Provide --reads, --longreads, or both!"
    }

    // C. Metagenomic Binning Track (Groups contigs into MAGs using abundance profile mapping)
    // FIXED: Passed ch_checkm2_db as the required 3rd argument to match your updated subworkflow
    BINNING_METAGENOMIC ( ch_raw_assembly, ch_mapping_reads, ch_checkm2_db )

    // D. Final Metagenomic Profiling & AMR Annotation
    // This loops over only the high-quality filtered MAGs discovered by CheckM2!
    ANNOTATION_AMR (
        BINNING_METAGENOMIC.out.filtered_mags,
        params.bakta_db,
        params.amrfinder_db
    )
}