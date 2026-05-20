process SIGNALP {
    tag "$meta.id"
    publishDir "${params.outdir}/04_secretome", mode: 'copy'

    input:
    tuple val(meta), path(proteins)

    output:
    tuple val(meta), path("*_summary.fasta"), emit: summary_fasta
    path "versions.yml"                     , emit: versions

    script:
    """
    signalp -fasta $proteins -org euk -format short -prefix ${meta.id}
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        signalp: \$(signalp --version)
    END_VERSIONS
    """

    stub:
    def prefix = "${meta.id}"
    """
    touch ${prefix}_summary.fasta
    touch versions.yml
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        signalp: stub_version
    END_VERSIONS
    """
}