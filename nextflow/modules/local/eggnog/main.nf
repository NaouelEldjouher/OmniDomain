process EGGNOG {
    tag "$meta.id"
    label 'process_high'

    input:
    tuple val(meta), path(proteins)

    output:
    tuple val(meta), path("*.emapper.annotations"), emit: annotations
    path "versions.yml"                           , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    emapper.py \\
        -i ${proteins} \\
        -o ${prefix} \\
        --cpu ${task.cpus} \\
        -m diamond

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        eggnog: \$(emapper.py --version | grep 'emapper' | awk '{print \$2}')
    END_VERSIONS
    """
}