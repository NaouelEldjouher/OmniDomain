process FUNANNOTATE {
    tag "$meta.id"
    label 'process_high' // Inherits 16 CPUs / 64GB RAM

    input:
    tuple val(meta), path(fasta)
    tuple val(meta), path(braker_gff)

    output:
    tuple val(meta), path("funannotate_out/predict_results/*.gff3")       , emit: gff3
    tuple val(meta), path("funannotate_out/predict_results/*.proteins.fa"), emit: proteins
    path "versions.yml"                                                   , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Funannotate requires a clean sort before prediction
    funannotate sort -i ${fasta} -o sorted.fa

    funannotate predict \\
        -i sorted.fa \\
        -o funannotate_out \\
        -s "${meta.id}" \\
        --other_gff ${braker_gff} \\
        --cpus ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        funannotate: \$( funannotate check --show-versions | grep 'funannotate' | awk '{print \$2}' )
    END_VERSIONS
    """
}