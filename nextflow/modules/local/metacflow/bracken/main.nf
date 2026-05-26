process BRACKEN {
    tag "$meta.id"
    label 'process_low'

    container 'quay.io/biocontainers/bracken:2.9--py310h0dbaff4_0'

    input:
    tuple val(meta), path(report)
    path db

    output:
    tuple val(meta), path("${meta.id}.bracken.txt"),        emit: txt
    tuple val(meta), path("${meta.id}.bracken_report.txt"), emit: report
    path "versions.yml",                                    emit: versions

    publishDir "${params.base_outdir}/metacflow/${params.sample_id}/05_taxonomy/bracken", mode: 'copy'

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: '-l S -t 10'
    def prefix = meta.id
    """
    bracken \\
        -d ${db} \\
        -i ${report} \\
        -o ${prefix}.bracken.txt \\
        -w ${prefix}.bracken_report.txt \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$(bracken --version 2>&1 | head -1 | sed 's/Bracken v//')
    END_VERSIONS
    """

    stub:
    def prefix = meta.id
    """
    touch ${prefix}.bracken.txt
    touch ${prefix}.bracken_report.txt
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: stub_2.9
    END_VERSIONS
    """
}
