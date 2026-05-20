process DBCAN {
    tag "$meta.id"
    publishDir "${params.outdir}/03_functional_annotation", mode: 'copy'

    input:
    tuple val(meta), path(proteins)

    output:
    tuple val(meta), path("*.overview.txt"), emit: overview
    path "versions.yml"                    , emit: versions

    script:
    """
    run_dbcan $proteins protein --out_dir ${meta.id}_dbcan --db_dir db/
    mv ${meta.id}_dbcan/overview.txt ${meta.id}.overview.txt
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dbcan: 4.0.stub
    END_VERSIONS
    """

    stub:
    def prefix = "${meta.id}"
    """
    touch ${prefix}.overview.txt
    touch versions.yml
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dbcan: stub_version
    END_VERSIONS
    """
}