process SAM_TO_BAM {
    tag "$meta.id"
    label 'process_low'

    container 'staphb/samtools:1.21'

    input:
    tuple val(meta), path(sam)

    output:
    tuple val(meta), path("${meta.id}.sorted.bam"), path("${meta.id}.sorted.bam.bai"), emit: bam
    path "versions.yml", emit: versions

    script:
    def prefix = meta.id
    """
    samtools view -bS ${sam} | samtools sort -o ${prefix}.sorted.bam
    samtools index ${prefix}.sorted.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """

    stub:
    def prefix = meta.id
    """
    touch ${prefix}.sorted.bam ${prefix}.sorted.bam.bai
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: stub_1.21
    END_VERSIONS
    """
}

process JGI_SUMMARIZE_DEPTH {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/metabat2:2.17--hd498684_0'

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("${meta.id}.depth.txt"), emit: depth
    path "versions.yml",                           emit: versions

    script:
    def prefix = meta.id
    """
    jgi_summarize_bam_contig_depths \
        --outputDepth ${prefix}.depth.txt \
        ${bam}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metabat2: 2.17
    END_VERSIONS
    """

    stub:
    def prefix = meta.id
    """
    printf "contigName\tcontigLen\ttotalAvgDepth\tsample.bam\tsample.bam-var\n" \
        > ${prefix}.depth.txt
    printf "k141_1\t1000\t10.0\t10.0\t0.1\n" >> ${prefix}.depth.txt
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metabat2: stub_2.17
    END_VERSIONS
    """
}
