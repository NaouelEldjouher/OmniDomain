process BUSCO {
    tag "$meta.id"
    label 'process_medium'

    input:
    tuple val(meta), path(fasta)
    val mode     // 'genome', 'transcriptome', or 'proteins'
    val lineage  // e.g., 'fungi_odb10' or 'embryophyta_odb10'

    output:
    tuple val(meta), path("busco_out/short_summary.*.txt"), emit: short_txt
    tuple val(meta), path("busco_out/*")                  , emit: full_dir
    path "versions.yml"                                   , emit: versions

    script:
    """
    busco \\
        -i ${fasta} \\
        -l ${lineage} \\
        -o busco_out \\
        -m ${mode} \\
        -c ${task.cpus} \\
        --force

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: \$( busco --version 2>&1 | sed 's/BUSCO //' )
    END_VERSIONS
    """
}