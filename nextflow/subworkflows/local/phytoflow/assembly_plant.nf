// subworkflows/local/plantflow/assembly_plant.nf

include { HIFIASM          } from '../../../modules/nf-core/hifiasm/main'
include { QUAST            } from '../../../modules/nf-core/quast/main'
include { MINIMAP2_ALIGN   } from '../../../modules/local/shared/minimap2/main'
include { SAMTOOLS_COVERAGE } from '../../../modules/local/shared/samtools/main'
include { BUSCO            } from '../../../modules/local/shared/busco/main'

// ── GFA to FASTA conversion ───────────────────────────────────────────────────
// Hifiasm outputs GFA (Graph Fragment Assembly) format
// All downstream tools require FASTA — convert once, reuse everywhere
process GFA_TO_FASTA {
    tag "${meta.id}"
    label 'process_single'

    input:
    tuple val(meta), path(gfa)

    output:
    tuple val(meta), path("${meta.id}_assembly.fasta"), emit: fasta
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    awk '/^S/ {print ">"\$2; print \$3}' ${gfa} > ${meta.id}_assembly.fasta

    # Validate output has sequences
    NSEQS=\$(grep -c "^>" ${meta.id}_assembly.fasta || echo 0)
    echo "INFO: GFA converted — \$NSEQS sequences in output FASTA"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version 2>&1 | head -1 | grep -oP '[\\d.]+' | head -1 || echo "system awk")
    END_VERSIONS
    """

    stub:
    """
    # Stub produces valid FASTA with sequence content
    # Empty FASTA causes cascade failures in downstream processes
    printf '>stub_contig_1\\nATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG\\n' \
        > ${meta.id}_assembly.fasta
    printf '>stub_contig_2\\nGCATGCATGCATGCATGCATGCATGCATGCATGCATGCATGCATGCAT\\n' \
        >> ${meta.id}_assembly.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: stub
    END_VERSIONS
    """
}

// ── ASSEMBLY_PLANT workflow ───────────────────────────────────────────────────
workflow ASSEMBLY_PLANT {
    take:
    ch_longreads // channel: [ val(meta), path(hifi.fastq.gz) ]
    ch_hic_reads // channel: [ val(meta), [path(hic_R1), path(hic_R2)] ] — may be empty

    main:
    ch_versions = Channel.empty()

    // ── 1. HIFIASM ──────────────────────────────────────────────────────────
    ch_hifiasm_reads = ch_longreads.map { meta, reads -> [ meta, reads, [] ] }

    ch_hifiasm_hic = ch_hic_reads
        .map { meta, reads -> [ meta, reads[0], reads[1] ] }
        .ifEmpty( [ [id:'hic_mock'], [], [] ] )


    ch_trio_mock = Channel.value( [ [id:'trio_mock'], [], [] ] )
    ch_bin_mock  = Channel.value( [ [id:'bin_mock'],  []     ] )

    HIFIASM( ch_hifiasm_reads, ch_trio_mock, ch_hifiasm_hic, ch_bin_mock )
    ch_versions = ch_versions.mix( HIFIASM.out.versions_hifiasm )

    // ── 2. PRIMARY CONTIG FILTER ────────────────────────────────────────────
    ch_primary_gfa = HIFIASM.out.primary_contigs.map { meta, files ->
        def primary = files instanceof List
            ? files.find { !it.name.contains('.bp.') } ?: files.first()
            : files
        return [ meta, primary ]
    }

    // ── 3. GFA → FASTA CONVERSION ───────────────────────────────────────────
    GFA_TO_FASTA( ch_primary_gfa )
    ch_assembly_fasta = GFA_TO_FASTA.out.fasta
    ch_versions       = ch_versions.mix( GFA_TO_FASTA.out.versions )

    // ── 4. ASSEMBLY QC — QUAST ──────────────────────────────────────────────
    ch_quast_gff_mock = Channel.value( [ [id:'quast_gff_mock'], [] ] )
    ch_quast_ref_mock = Channel.value( [ [id:'quast_ref_mock'], [] ] )

    QUAST( ch_assembly_fasta, ch_quast_gff_mock, ch_quast_ref_mock )
    // ch_versions = ch_versions.mix( QUAST.out.versions )

    // ── 5. ASSEMBLY QC — BUSCO ──────────────────────────────────────────────
    BUSCO( ch_assembly_fasta, 'genome', 'embryophyta_odb10' )
    ch_versions = ch_versions.mix( BUSCO.out.versions )

    // ── 6. COVERAGE DEPTH VALIDATION ────────────────────────────────────────
    ch_map_inputs = ch_longreads.join( ch_assembly_fasta )

    MINIMAP2_ALIGN( ch_map_inputs )
    ch_versions = ch_versions.mix( MINIMAP2_ALIGN.out.versions )

    SAMTOOLS_COVERAGE( MINIMAP2_ALIGN.out.sam )
    ch_versions = ch_versions.mix( SAMTOOLS_COVERAGE.out.versions )

    // ── EMIT ────────────────────────────────────────────────────────────────
    emit:
    assembly = ch_assembly_fasta           // [ meta, fasta ] — primary assembly FASTA
    quast    = QUAST.out.tsv               // [ meta, tsv ]  — assembly statistics
    busco    = BUSCO.out.short_txt         // [ meta, txt ]  — BUSCO completeness
    coverage = SAMTOOLS_COVERAGE.out.coverage // [ meta, txt ] — per-contig coverage
    versions = ch_versions                 // versions for MultiQC
}
