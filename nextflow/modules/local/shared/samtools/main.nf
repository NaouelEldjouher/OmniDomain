process SAMTOOLS_COVERAGE {
    tag "$meta.id"
    label 'process_low'

    container 'staphb/samtools:1.21'

    input:
    tuple val(meta), path(sam)

    output:
    tuple val(meta), path("${meta.id}.coverage.txt"), emit: coverage
    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = meta.id
    """
    samtools view -bS ${sam} | samtools sort -o ${prefix}.bam
    samtools index ${prefix}.bam
    samtools coverage ${prefix}.bam > ${prefix}.coverage.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """

    stub:
    def prefix = meta.id
    """
    touch ${prefix}.coverage.txt
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: stub_1.21
    END_VERSIONS
    """
}

process SAMTOOLS_DEPTH {
    tag "$meta.id"
    label 'process_low'

    container 'staphb/samtools:1.21'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("${meta.id}.depth.txt"), emit: depth
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = meta.id
    """
    samtools sort -o ${prefix}.sorted.bam ${bam}
    samtools index ${prefix}.sorted.bam
    samtools depth -aa ${prefix}.sorted.bam > ${prefix}.depth.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """

    stub:
    def prefix = meta.id
    """
    touch ${prefix}.depth.txt
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: stub_1.21
    END_VERSIONS
    """
}
