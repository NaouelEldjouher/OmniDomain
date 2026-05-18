process REPEATMASKER {
    tag "$meta.id"
    label 'process_high'

    input:
    tuple val(meta), path(fasta)
    path repeat_library // The fasta library of repeats to mask against

    output:
    tuple val(meta), path("*.masked"), emit: masked_fasta
    tuple val(meta), path("*.tbl")   , emit: summary_table
    path "versions.yml"              , emit: versions

    script:
    // -xsmall converts masked regions to lowercase (soft-masking) rather than N's (hard-masking)
    """
    RepeatMasker \\
        -pa ${task.cpus} \\
        -xsmall \\
        -lib ${repeat_library} \\
        -dir . \\
        ${fasta}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        repeatmasker: \$(RepeatMasker -v | awk '{print \$3}')
    END_VERSIONS
    """
}