process CHECKM2 {
    tag "$meta.id"
    label 'process_high'

    publishDir "${params.outdir}/02_binning/filtered_mags", mode: 'copy'
    container 'chklovski/checkm2:1.0.2'

    input:
    tuple val(meta), path(bins_folder)

    output:
    tuple val(meta), path("high_quality_mags/*.fasta"), emit: filtered_mags
    path "versions.yml"                               , emit: versions

    script:
    """
    checkm2 predict \\
        --input $bins_folder \\
        --output_dir checkm2_out \\
        --threads $task.cpus

    # Filter out bins with >90% completeness and <5% contamination
    mkdir -p high_quality_mags
    awk -F'\\t' 'NR>1 { if(\$2 >= 90.0 && \$3 <= 5.0) print \$1 }' checkm2_out/quality_report.tsv | while read bin; do
        cp "${bins_folder}/\${bin}.fa" "high_quality_mags/\${bin}.fasta" 2>/dev/null || true
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        checkm2: \$(checkm2 --version 2>&1)
    END_VERSIONS
    """

    stub:
    """
    mkdir -p high_quality_mags
    touch high_quality_mags/bin.1.fasta
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        checkm2: stub_version
    END_VERSIONS
    """
}
