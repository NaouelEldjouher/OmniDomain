process NLR_ANNOTATOR {
    tag "$meta.id"
    label 'process_medium'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.nlr.txt"), emit: results
    path "versions.yml"               , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    java -jar /opt/NLR-Annotator.jar -i ${fasta} -x ${prefix}.motifs.xml -y ${prefix}.nlr.txt -t ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nlr_annotator: "1.0"
    END_VERSIONS
    """
}