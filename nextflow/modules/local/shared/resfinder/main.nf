process RESFINDER {
    tag "$meta.id"
    label 'process_low'

    container 'quay.io/biocontainers/resfinder:4.3.2--pyhdfd78af_0'

    input:
    tuple val(meta), path(fasta), path(reads1), path(reads2)
    path db

    output:
    tuple val(meta), path("${meta.id}_resfinder/"), emit: results
    path "versions.yml",                            emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = meta.id
    """
    python -m resfinder \\
        -i ${fasta} \\
        -o ${prefix}_resfinder \\
        -s "Other" \\
        --acquired \\
        --db_path_res ${db} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        resfinder: \$(python -m resfinder --version 2>&1 | head -1)
    END_VERSIONS
    """

    stub:
    def prefix = meta.id
    """
    mkdir -p ${prefix}_resfinder
    touch ${prefix}_resfinder/ResFinder_results.txt
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        resfinder: stub_4.3.2
    END_VERSIONS
    """
}
