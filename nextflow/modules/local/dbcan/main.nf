process DBCAN {
    tag "$meta.id"
    label 'process_medium'

    input:
    tuple val(meta), path(proteins)

    output:
    tuple val(meta), path("dbcan_out/overview.txt"), emit: overview
    path "versions.yml"                            , emit: versions

    script:
    """
    run_dbcan ${proteins} protein \\
        --out_dir dbcan_out \\
        --dia_cpu ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dbcan: \$(run_dbcan --version | awk '{print \$2}')
    END_VERSIONS
    """
}