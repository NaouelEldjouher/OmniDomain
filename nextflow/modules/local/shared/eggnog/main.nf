process EGGNOG {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine in ['singularity', 'apptainer'] ?
        'https://depot.galaxyproject.org/singularity/eggnog-mapper:2.1.12--pyhdfd78af_0' :
        'quay.io/biocontainers/eggnog-mapper:2.1.12--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(proteins)

    output:
    tuple val(meta), path("*.emapper.annotations"), emit: annotations
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix   = task.ext.prefix ?: "${meta.id}"
    def args     = task.ext.args   ?: '--no_annot --no_file_comments'
    def data_dir = params.eggnog_db_dir ? "--data_dir /eggnog_db" : ""
    """
    if [ ! -s "${proteins}" ]; then
        echo "WARNING: Empty protein file — creating empty annotation"
        touch ${prefix}.emapper.annotations
    else
        NPROTEINS=\$(grep -c "^>" ${proteins} || echo 0)
        echo "INFO: Running eggNOG-mapper on \$NPROTEINS proteins"
        emapper.py \
            -i ${proteins} \
            --output ${prefix} \
            --cpu ${task.cpus} \
            ${data_dir} \
            ${args}
    fi
    echo '"${task.process}":' > versions.yml
    echo '    eggnog-mapper: 2.1.12' >> versions.yml
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.emapper.annotations
    echo '"${task.process}":' > versions.yml
    echo '    eggnog-mapper: stub_2.1.12' >> versions.yml
    """
}
