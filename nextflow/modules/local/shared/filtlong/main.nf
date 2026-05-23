process FILTLONG {
    tag "$meta.id"
    label 'process_low'

    container 'quay.io/biocontainers/filtlong:0.2.1--h9a82719_0'

    input:
    tuple val(meta), path(shortreads), path(longreads)

    output:
    tuple val(meta), path("*.fastq.gz"), emit: reads
    tuple val(meta), path("*.log")     , emit: log
    path "versions.yml"                , emit: versions_filtlong

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args   = task.ext.args   ?: ''
    """
    filtlong ${args} ${longreads} 2> >(tee ${prefix}.log >&2) | gzip > ${prefix}.fastq.gz
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf '@stub\nACGT\n+\nIIII\n' | gzip > ${prefix}.filtered.fastq.gz
    touch ${prefix}.log
    echo '"${task.process}":' > versions.yml
    echo '    filtlong: stub' >> versions.yml
    """
}
