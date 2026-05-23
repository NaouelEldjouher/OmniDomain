process EDTA {
    tag "$meta.id"
    label 'process_high'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.TElib.fa"), emit: te_library
    tuple val(meta), path("*.gff3")    , emit: te_gff
    path "versions.yml"                , emit: versions

    script:
    """
    EDTA.pl --genome ${fasta} --threads ${task.cpus} --sensitive 1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        edta: \$(EDTA.pl --version | awk '{print \$2}')
    END_VERSIONS
    """
}