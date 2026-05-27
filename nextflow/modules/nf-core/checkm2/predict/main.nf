process CHECKM2_PREDICT {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0a/0af812c983aeffc99c0fca9ed2c910816b2ddb9a9d0dcad7b87dab0c9c08a16f/data':
        'community.wave.seqera.io/library/checkm2:1.1.0--60f287bc25d7a10d' }"

    input:
    tuple val(meta), path(fasta, stageAs: "input_bins/*")
    tuple val(dbmeta), path(db)

    output:
    tuple val(meta), path("${prefix}")                   , emit: checkm2_output
    tuple val(meta), path("${prefix}_checkm2_report.tsv"), emit: checkm2_tsv
    path "versions.yml"                           , emit: versions
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """

    # Handle 0-bin case — MetaBAT2 produces empty stubs when coverage is too low
    REAL_BINS=\$(find -L . -maxdepth 1 -name "*.fa.gz" -size +100c 2>/dev/null | wc -l)
    if [ "$REAL_BINS" -gt 0 ]; then
        checkm2 \
            predict \
            --input ${fasta} \
            --output-directory ${prefix} \
            --threads ${task.cpus} \
            --database_path ${db} \
            ${args}
        cp ${prefix}/quality_report.tsv ${prefix}_checkm2_report.tsv
    else
        echo "INFO: No real bins found — skipping CheckM2 assessment"
        mkdir -p ${prefix}
        printf "Name\tCompleteness\tContamination\tCompleteness_Model_Used\tTranslation_Table_Used\tCoding_Density\tContig_N50\tAverage_Gene_Length\tGenome_Size\tGC_Content\tTotal_Coding_Sequences\tAdditional_Notes\n" \
            > ${prefix}_checkm2_report.tsv
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        checkm2: 1.0.1
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir ${prefix}/
    touch ${prefix}_checkm2_report.tsv

    # FIXED: Added stub creation for versions.yml to satisfy output tracking
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        checkm2: stub_version
    END_VERSIONS
    """
}
