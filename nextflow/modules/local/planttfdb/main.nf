process PLANTTFDB {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(proteins)

    output:
    tuple val(meta), path("*.tf_predictions.tsv"), emit: results
    path "versions.yml"                          , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Assuming a standard blast/hmmsearch against the PlantTFDB local copy
    hmmsearch --cpu ${task.cpus} --tblout ${prefix}.tf_predictions.tsv /path/to/planttfdb.hmm ${proteins}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        planttfdb: "custom_hmm_search"
    END_VERSIONS
    """
}