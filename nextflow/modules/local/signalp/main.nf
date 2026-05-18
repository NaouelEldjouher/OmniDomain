process SIGNALP {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(proteins)

    output:
    tuple val(meta), path("*_summary.fasta"), emit: summary_fasta
    path "versions.yml"                     , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    signalp \\
        -fasta ${proteins} \\
        -org euk \\
        -format short \\
        -prefix ${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        signalp: \$(signalp -version 2>&1 | awk '{print \$2}')
    END_VERSIONS
    """
}