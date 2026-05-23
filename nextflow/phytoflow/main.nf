#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
 * ============================================================================
 * OmniDomain — PhytoFlow Pipeline
 * HiFi-first plant genome assembly, annotation & comparative genomics
 * Author: Naouel El Djouher
 * ============================================================================
 *
 * Three execution modes — selected automatically from --genome_type and --reference:
 *
 *   Mode 1 — Organelle assembly (default)
 *     nextflow run phytoflow/main.nf --genome_type organelle --hifi_reads reads.fastq.gz
 *     Runs: QC → Assembly → QUAST/BUSCO/Coverage → RepeatMasking
 *     Skips: Scaffolding, Helixer, MAKER, secondary metabolites, functional annotation
 *
 *   Mode 2 — Nuclear de novo (HiFi only, no reference)
 *     nextflow run phytoflow/main.nf --genome_type nuclear --hifi_reads reads.fastq.gz
 *     Runs: all steps + Helixer (deep learning gene prediction)
 *     Skips: Reference scaffolding, MAKER
 *
 *   Mode 3 — Nuclear with reference (highest quality)
 *     nextflow run phytoflow/main.nf --genome_type nuclear --hifi_reads reads.fastq.gz \
 *                                    --reference ref.fna.gz
 *     Runs: all steps + RagTag scaffolding + MAKER (evidence-based annotation)
 *     Skips: Helixer
 * ============================================================================
 */

/*
 * 1. IMPORT SHARED CORE SUBWORKFLOWS
 */
include { QC_HIFI        } from '../subworkflows/local/shared/qc_hifi'
include { REPEAT_MASKING } from '../subworkflows/local/shared/repeat_masking'

/*
 * 2. IMPORT PHYTOFLOW-SPECIFIC SUBWORKFLOWS
 */
include { ASSEMBLY_PLANT        } from '../subworkflows/local/phytoflow/assembly_plant'
include { SCAFFOLDING           } from '../subworkflows/local/phytoflow/scaffolding'
include { ANNOTATION_STRUCTURAL } from '../subworkflows/local/phytoflow/annotation_structural'
include { ANNOTATION_FUNCTIONAL } from '../subworkflows/local/phytoflow/annotation_functional'
include { SECONDARY_METABOLITES } from '../subworkflows/local/phytoflow/secondary_metabolites'
include { COMPARATIVE_PLANT     } from '../subworkflows/local/phytoflow/comparative_plant'
include { EXTRACT_PROTEOME      } from '../modules/local/extract_proteome/main'

/*
 * 3. MAIN WORKFLOW
 */
workflow {
    log.info "DEBUG genome_type: '${params.genome_type}'"
    log.info "DEBUG reference:   '${params.reference}'"

    // ── A. AUTO-DETECTION: determine annotation mode from inputs ────────────
 
    // ── A. AUTO-DETECTION ───────────────────────────────────────────────────
    def genome     = params.genome_type ?: 'organelle'
    def has_ref    = params.reference   ?: false
    def do_helixer = ( genome == 'nuclear' && !has_ref )
    def do_maker   = ( genome == 'nuclear' &&  has_ref )

    log.info ">>> genome_type : ${genome}"
    log.info ">>> reference   : ${has_ref ?: 'none'}"
    log.info ">>> do_helixer  : ${do_helixer}"
    log.info ">>> do_maker    : ${do_maker}"
    if      ( do_helixer ) log.info ">>> MODE: Nuclear de novo — Helixer enabled"
    else if ( do_maker   ) log.info ">>> MODE: Nuclear + Reference — MAKER enabled"
    else                   log.info ">>> MODE: Organelle — annotation skipped"
    // ── B. SAMPLE ID ─────────────────────────────────────────────────────────
    def sample_id = params.sample_id ?: 'sample'
    log.info ">>> sample_id  : ${sample_id}"
    log.info ">>> genome_type: ${genome}"
    log.info ">>> outdir     : ${params.base_outdir}/phytoflow/${sample_id}"

    // ── B. PRE-FLIGHT VALIDATION ─────────────────────────────────────────────
    // Validate Helixer model directory when Helixer will run
    if ( do_helixer ) {
        if ( !params.helixer_models_dir ) {
            exit 1, "PIPELINE ERROR: --helixer_models_dir required for nuclear de novo mode"
        }
        def helixer_dir = file(params.helixer_models_dir)
        if ( !helixer_dir.exists() ) {
            exit 1, """
            PIPELINE ERROR: Helixer model directory not found: ${params.helixer_models_dir}
            Download models: fetch_helixer_models.py --lineage land_plant
            Or disable with: --genome_type organelle
            """
        }
    }

    // HiFi reads are mandatory for all modes
    if ( !params.hifi_reads ) {
        error "PIPELINE ERROR: PhytoFlow requires --hifi_reads (PacBio HiFi .fastq.gz)"
    }

    // NLR-Annotator assets required for nuclear mode
    if ( params.genome_type == 'nuclear' ) {
        if ( !params.nlr_jar || !params.nlr_mot || !params.nlr_store ) {
            exit 1, """
            PIPELINE ERROR: Nuclear mode requires NLR-Annotator assets:
              --nlr_jar   path/to/NLR-Annotator.jar
              --nlr_mot   path/to/mot.txt
              --nlr_store path/to/store.txt
            Or set in nextflow.config params block.
            """
        }
    }

    // ── C. INPUT PARSING ─────────────────────────────────────────────────────
    // HiFi reads — mandatory for all modes
    ch_hifi_reads = Channel
        .fromPath( params.hifi_reads, checkIfExists: true )
        .map { file -> [ [id: file.simpleName], file ] }

    // Hi-C reads — optional, activates Hifiasm Hi-C phasing + YAHS scaffolding
    ch_hic_reads = params.hic_reads
        ? Channel.fromFilePairs( params.hic_reads, checkIfExists: true )
            .map { id, reads -> [ [id: id], reads ] }
        : Channel.empty()

    // Scaffolding inputs — Hi-C BAM map and/or reference genome for RagTag
    ch_hic_map_track = params.hic_map
        ? Channel.fromPath( params.hic_map, checkIfExists: true )
            .map { f -> [ [id: 'hic_map'], f ] }
        : Channel.empty()

    ch_ref_track = params.reference
        ? Channel.fromPath( params.reference, checkIfExists: true )
            .map { f -> [ [id: 'ref'], f ] }
        : Channel.empty()

    // Annotation evidence — optional RNA-seq transcriptome and protein hints for MAKER
    ch_transcriptome_track = params.transcriptome
        ? Channel.fromPath( params.transcriptome, checkIfExists: true )
            .map { f -> [ [id: 'tx'], f ] }
        : Channel.of( [ [id: 'tx_empty'], [] ] )

    ch_proteins_track = params.proteins
        ? Channel.fromPath( params.proteins, checkIfExists: true )
            .map { f -> [ [id: 'prot'], f ] }
        : Channel.of( [ [id: 'prot_empty'], [] ] )

    // NLR-Annotator assets — passed as channels for S3 compatibility
    // Only parsed when genome_type = nuclear (validated above)
    ch_nlr_jar   = params.genome_type == 'nuclear'
        ? Channel.fromPath( params.nlr_jar,   checkIfExists: true )
        : Channel.empty()
    ch_nlr_mot   = params.genome_type == 'nuclear'
        ? Channel.fromPath( params.nlr_mot,   checkIfExists: true )
        : Channel.empty()
    ch_nlr_store = params.genome_type == 'nuclear'
        ? Channel.fromPath( params.nlr_store, checkIfExists: true )
        : Channel.empty()

    // ── D. QC — HiFi-specific ────────────────────────────────────────────────
    // HiFiAdapterFilt: removes PacBio SMRTbell adapter contamination
    // seqkit stats: read N50, total bases, read count for QC report
   
    QC_HIFI( ch_hifi_reads )

    // ── E. ASSEMBLY ──────────────────────────────────────────────────────────
    // Hifiasm: best-in-class HiFi assembler, supports Hi-C phasing
    // GFA_TO_FASTA: converts assembly graph to FASTA for downstream tools
    // QUAST + BUSCO + minimap2 coverage: validates assembly quality
    ASSEMBLY_PLANT( QC_HIFI.out.reads, ch_hic_reads )

    // Filter to primary contig — HIFIASM emits both p_ctg and bp.p_ctg
    ch_primary_assembly = ASSEMBLY_PLANT.out.assembly.map { meta, files ->
        def primary = files instanceof List
            ? files.find { !it.name.contains('.bp.') } ?: files.first()
            : files
        return [ meta, primary ]
    }

    // ── F. SCAFFOLDING ───────────────────────────────────────────────────────
    // Nuclear: YAHS (Hi-C) or RagTag (reference) → chromosome-level assembly
    // Organelle: skip — organelle contigs are complete circular molecules
    if ( params.genome_type == 'nuclear' ) {
    SCAFFOLDING( ch_primary_assembly, ch_hic_map_track, ch_ref_track )
    ch_scaffolded = SCAFFOLDING.out.scaffolds
    } else {
    log.info "INFO: Scaffolding skipped — organelle mode"
    ch_scaffolded = ch_primary_assembly
    }


    // ── G. REPEAT MASKING ────────────────────────────────────────────────────
    // RepeatModeler: builds organism-specific repeat library de novo
    // RepeatMasker: soft-masks repeats (lowercase) — required before gene prediction
    // Expected masking: organelles <5%, nuclear plants 40-85%
    REPEAT_MASKING( ch_scaffolded )

    // ── H. STRUCTURAL ANNOTATION ─────────────────────────────────────────────
    // Mode 1 (organelle): both skipped — no nuclear genes to predict
    // Mode 2 (nuclear de novo): Helixer runs, MAKER skipped
    // Mode 3 (nuclear + reference): MAKER runs, Helixer skipped
    ANNOTATION_STRUCTURAL(
        REPEAT_MASKING.out.masked_fasta,
        ch_transcriptome_track,
        ch_proteins_track,
        do_helixer,
        do_maker
    )

    // ── I. ANNOTATION GFF ROUTING ────────────────────────────────────────────
    // Priority: MAKER > Helixer > empty
    // Used by SECONDARY_METABOLITES and EXTRACT_PROTEOME
    ch_annotation_gff = do_maker
        ? ANNOTATION_STRUCTURAL.out.maker_gff
        : do_helixer
            ? ANNOTATION_STRUCTURAL.out.helixer_gff
            : Channel.empty()

    // ── J. SECONDARY METABOLITES & DEFENSE ──────────────────────────────────
    // Nuclear only — organelle genomes have no BGCs or NLR R genes
    // NLR-Annotator: NBS-LRR disease resistance gene detection (sequence-based)
    if ( params.genome_type == 'nuclear' ) {
        SECONDARY_METABOLITES(
            REPEAT_MASKING.out.masked_fasta,
            ch_annotation_gff,
            ch_nlr_jar,
            ch_nlr_mot,
            ch_nlr_store
        )
    } else {
        log.info "INFO: Secondary metabolites skipped — organelle mode"
    }

    // ── K. PROTEOME EXTRACTION + FUNCTIONAL ANNOTATION ───────────────────────
    // Runs only when annotation GFF is available (MAKER or Helixer produced output)
    // EXTRACT_PROTEOME: masked FASTA + GFF → protein FASTA (AGAT)
    // ANNOTATION_FUNCTIONAL: proteins → GO terms + KEGG + TF identification
    if ( params.genome_type == 'nuclear' && ( do_maker || do_helixer ) ) {

    // Convert BRAKER3 GTF → GFF3 if BRAKER3 ran
    // Helixer already outputs GFF3 — no conversion needed
    ch_gff_for_extraction = do_maker
        ? ch_annotation_gff.map { meta, gtf ->
            // AGAT in EXTRACT_PROTEOME handles GTF directly
            // No explicit conversion needed — AGAT auto-detects format
            [ meta, gtf ]
          }
        : ch_annotation_gff

    ch_protein_extraction_input = REPEAT_MASKING.out.masked_fasta
        .join( ch_gff_for_extraction )

    EXTRACT_PROTEOME( ch_protein_extraction_input )
    ANNOTATION_FUNCTIONAL( EXTRACT_PROTEOME.out.proteome )

        // ── L. COMPARATIVE GENOMICS (optional) ──────────────────────────────
        // Multi-sample only — OrthoFinder + MCScanX
        // Activate with: --run_comparative true
         if ( params.run_comparative ) {
        ch_collected_proteomes = EXTRACT_PROTEOME.out.proteome
            .map { meta, fasta -> fasta }
            .collect()

        ch_collected_gffs = ch_annotation_gff
            .map { meta, gff -> gff }
            .collect()

        COMPARATIVE_PLANT( ch_collected_proteomes, ch_collected_gffs )
    }
    } else {
    log.info "INFO: Proteome extraction and functional annotation skipped"
    if ( params.genome_type == 'organelle' ) {
        log.info "INFO: Use --genome_type nuclear for full annotation pipeline"
    }}
}


