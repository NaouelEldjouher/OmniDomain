process ANTISMASH {
    tag "$meta.id"
    label 'process_medium'

    input:
    tuple val(meta), path(fasta)
    tuple val(meta_gff), path(gff)

    output:
    tuple val(meta), path("antismash_output"), emit: results
    path "versions.yml"                      , emit: versions

    script:
    // Uses the --taxon plants argument injected from your modules.config!
    def args = task.ext.args ?: '' 
    """
    antismash \\
        --genefinding-gff3 ${gff} \\
        --cpus ${task.cpus} \\
        --output-dir antismash_output \\
        ${args} \\
        ${fasta}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        antismash: \$(antismash --version | sed 's/antiSMASH //')
    END_VERSIONS
    """
}