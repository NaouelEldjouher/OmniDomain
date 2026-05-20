process SPADES {
    tag "$meta.id"
    label 'process_high'

    input:
    tuple val(meta), path(shortreads)
    tuple val(meta_long), path(longreads)

    output:
    tuple val(meta), path("spades_out/scaffolds.fasta"), emit: scaffolds
    path "versions.yml"                               , emit: versions

    script:
    """
    # Run SPAdes in hybrid metagenomics co-assembly mode
    spades.py \\
        --meta \\
        -1 ${shortreads[0]} \\
        -2 ${shortreads[1]} \\
        --nanopore $longreads \\
        -t $task.cpus \\
        -m ${task.memory.toGiga()} \\
        -o spades_out

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        spades: \$(spades.py --version 2>&1 | head -n 1 | grep -oE "[0-9.]+")
    END_VERSIONS
    """

    stub:
    """
    mkdir -p spades_out
    touch spades_out/scaffolds.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        spades: stub_version
    END_VERSIONS
    """
}
