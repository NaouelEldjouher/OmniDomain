process RAGTAG {
    tag "$meta.id"
    label 'process_medium'

    input:
    tuple val(meta), path(fasta)
    tuple val(meta), path(reference)

    output:
    tuple val(meta), path("ragtag.scaffold.fasta"), emit: scaffolds
    path "versions.yml"                           , emit: versions

    script:
    """
    ragtag.py scaffold -t ${task.cpus} ${reference} ${fasta}
    
    cp ragtag_output/ragtag.scaffold.fasta ./

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ragtag: \$(ragtag.py --version)
    END_VERSIONS
    """
}