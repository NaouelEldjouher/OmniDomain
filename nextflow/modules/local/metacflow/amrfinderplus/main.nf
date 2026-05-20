process AMRFINDERPLUS {
    tag "$meta.id"

    publishDir "${params.outdir}/amrfinderplus", mode: 'copy'

    input:
    tuple val(meta), path(fasta)
    path amr_path

    output:
    tuple val(meta), path("*.tsv"), emit: report
    path "versions.yml"           , emit: versions

    when:
    !params.skip_amr

    script:
    def prefix = "${meta.id}"
    def organism_flag = meta.organism ? "-O \"${meta.organism}\"" : ""
    """
    amrfinder \\
        -n $fasta \\
        -d $amr_path \\
        --threads $task.cpus \\
        --plus \\
        $organism_flag \\
        -o ${prefix}_amr.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        amrfinderplus: \$(amrfinder --version)
    END_VERSIONS
    """

    // FIXED: Added mock simulation block for safe, offline stub tracking
    stub:
    def prefix = "${meta.id}"
    """
    touch ${prefix}_amr.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        amrfinderplus: stub_version
    END_VERSIONS
    """
}