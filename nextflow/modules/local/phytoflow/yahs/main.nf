process YAHS {
    tag "$meta.id"
    label 'process_high'

    input:
    tuple val(meta), path(fasta)
    tuple val(meta), path(hic_bam)

    output:
    tuple val(meta), path("*_scaffolds_final.fa"), emit: scaffolds
    path "versions.yml"                          , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    yahs ${fasta} ${hic_bam} -o ${prefix}
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        yahs: \$(yahs --version)
    END_VERSIONS
    """
}