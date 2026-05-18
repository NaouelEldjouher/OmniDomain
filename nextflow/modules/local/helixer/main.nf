process HELIXER {
    tag "$meta.id"
    label 'process_high'

    // We allow a specific container override here if the user has a GPU-enabled image
    container "gglusman/helixer:0.3.3" 

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.gff3"), emit: gff
    path "versions.yml"            , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    Helixer.py \\
        --fasta-path ${fasta} \\
        --lineage land_plant \\
        --gff-output-path ${prefix}.helixer.gff3 \\
        --species ${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        helixer: \$( Helixer.py --version | sed 's/Helixer //' )
    END_VERSIONS
    """
}