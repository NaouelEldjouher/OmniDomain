process JGI_SUMMARIZE_DEPTH {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/metabat2:2.17--hd498684_0'

    input:
    tuple val(meta), path(sam)

    output:
    tuple val(meta), path("${meta.id}.depth.txt"), emit: depth
    path "versions.yml",                           emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = meta.id
    """
    samtools view -bS ${sam} | samtools sort -o ${prefix}.bam
    samtools index ${prefix}.bam
    jgi_summarize_bam_contig_depths \
        --outputDepth ${prefix}.depth.txt \
        ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metabat2: \$(metabat2 --help 2>&1 | head -2 | tail -1 | sed 's/.*(\(.*\)).*/\1/')
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
