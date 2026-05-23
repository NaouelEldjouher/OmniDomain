process PROKKA {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/prokka:1.14.6--pl5321hdfd78af_4'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}/*.gff"), emit: gff
    tuple val(meta), path("${meta.id}/*.faa"), emit: faa
    tuple val(meta), path("${meta.id}/*.txt"), emit: txt
    path "versions.yml",                       emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = meta.id
    """
    prokka \\
        --outdir ${prefix} \\
        --prefix ${prefix} \\
        --metagenome \\
        --cpus ${task.cpus} \\
        ${args} \\
        ${fasta}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        prokka: \$(prokka --version 2>&1 | sed 's/prokka //')
    END_VERSIONS
    """

    stub:
    def prefix = meta.id
    """
    mkdir -p ${prefix}
    touch ${prefix}/${prefix}.gff
    touch ${prefix}/${prefix}.faa
    touch ${prefix}/${prefix}.txt
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        prokka: stub_1.14.6
    END_VERSIONS
    """
}
