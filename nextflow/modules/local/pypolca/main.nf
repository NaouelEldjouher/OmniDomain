process PYPOLCA {
    tag "$meta.id"
   

    publishDir "${params.outdir}/pypolca", mode: 'copy', pattern: '*.fasta'

    input:
    tuple val(meta), path(assembly), path(reads)

    output:

    tuple val(meta), path("${meta.id}_pypolca.fasta"), emit: assembly
    path "versions.yml"                              , emit: versions

    script:
    """
    
    pypolca run \\
        -a $assembly \\
        -1 ${reads[0]} \\
        -2 ${reads[1]} \\
        -t $task.cpus \\
        -o pypolca_out \\
        -p ${meta.id}

    # Move the file out of the folder and rename it so Nextflow is happy
    mv pypolca_out/${meta.id}_corrected.fasta ${meta.id}_pypolca.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pypolca: \$(pypolca --version 2>&1 | sed 's/pypolca //')
    END_VERSIONS
    """
}