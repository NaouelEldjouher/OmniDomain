process REPEATMODELER {
    tag "$meta.id"
    label 'process_high'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*-families.fa"), emit: repeat_library
    path "versions.yml"                   , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    BuildDatabase -name ${prefix} ${fasta}
    RepeatModeler -database ${prefix} -pa ${task.cpus}

    cp RM_*/consensi.fa.classified ${prefix}-families.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        repeatmodeler: \$(RepeatModeler -v | awk '{print \$3}')
    END_VERSIONS
    """
}