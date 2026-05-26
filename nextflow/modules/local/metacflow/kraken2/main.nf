process KRAKEN2 {
    tag "$meta.id"
    label 'process_high'

    container 'staphb/kraken2:latest'

    input:
    tuple val(meta), path(reads)
    path db

    output:
    tuple val(meta), path("${meta.id}.kraken2.report.txt"), emit: report
    tuple val(meta), path("${meta.id}.kraken2.output.txt"), emit: output
    path "versions.yml",                                    emit: versions

    publishDir [
        path: { "${params.base_outdir}/metacflow/${params.sample_id}/05_taxonomy/kraken2" },
        mode: "copy"
    ]

    when:
    task.ext.when == null || task.ext.when

    script:
    def args     = task.ext.args ?: ''
    def prefix   = meta.id
    def paired   = meta.single_end ? "${reads}" : "--paired ${reads[0]} ${reads[1]}"
    """
    kraken2 \\
        --db ${db} \\
        --threads ${task.cpus} \\
        --report ${prefix}.kraken2.report.txt \\
        --output ${prefix}.kraken2.output.txt \\
        ${args} \\
        ${paired}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(kraken2 --version 2>&1 | head -1 | sed 's/Kraken version //')
    END_VERSIONS
    """

    stub:
    def prefix = meta.id
    """
    touch ${prefix}.kraken2.report.txt
    touch ${prefix}.kraken2.output.txt
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: stub_2.1.3
    END_VERSIONS
    """
}
