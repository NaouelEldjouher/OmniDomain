process EGGNOG {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine in ['singularity', 'apptainer'] ?
        'https://depot.galaxyproject.org/singularity/eggnog-mapper:2.1.12--pyhdfd78af_0' :
        'quay.io/biocontainers/eggnog-mapper:2.1.12--pyhdfd78af_0' }"

    publishDir "${params.outdir}/08_functional/eggnog", mode: 'copy'

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
    // Only add --data_dir if database is mounted
    def data_dir = params.eggnog_db_dir ? "--data_dir /eggnog_db" : ""
    """
    #!/bin/bash
    set -eo pipefail

    if [ ! -s "${proteins}" ]; then
        echo "WARNING: Empty protein file — creating empty annotation"
        touch ${prefix}.emapper.annotations
    else
        NPROTEINS=\$(grep -c "^>" ${proteins} || echo 0)
        echo "INFO: Running eggNOG-mapper on \$NPROTEINS proteins"

        emapper.py \\
            -i ${proteins} \\
            --output ${prefix} \\
            --cpu ${task.cpus} \\
            ${data_dir} \\
            ${args}
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        eggnog-mapper: \$(emapper.py --version 2>&1 | grep -oP 'emapper-[\\d.]+' | head -1 || echo "2.1.12")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.emapper.annotations

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        eggnog-mapper: stub_2.1.12
    END_VERSIONS
    """
}