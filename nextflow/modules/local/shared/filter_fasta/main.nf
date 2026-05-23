process FILTER_FASTA {
    tag "${meta.id}"
    label 'process_low'
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] ?
        'https://depot.galaxyproject.org/singularity/seqkit:2.9.0--h9ee0642_0' :
        'quay.io/biocontainers/seqkit:2.9.0--h9ee0642_0' }"


    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("filtered.fasta"), emit: fasta

    script:
    // This removes sequences < 1000bp, preventing the Helixer AxisError
    """
    seqkit seq -m 1000 ${fasta} > filtered.fasta
    """
}