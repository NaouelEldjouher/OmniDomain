process METABAT2 {
    tag "$meta.id"
    label 'process_medium'

    publishDir "${params.outdir}/02_binning/raw_bins", mode: 'copy'


    input:
    tuple val(meta), path(assembly), path(depth)

    output:
    tuple val(meta), path("bins_dir/*"), emit: bins
    path "versions.yml"                 , emit: versions

    script:
    """
    mkdir -p bins_dir
    metabat2 \\
        -i $assembly \\
        -a $depth \\
        -o bins_dir/bin \\
        -t $task.cpus

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metabat2: \$(metabat2 -h 2>&1 | head -n 1 | grep -oE "version [0-9.]+")
    END_VERSIONS
    """

    stub:
    """
    mkdir -p bins_dir
    touch bins_dir/bin.1.fa bins_dir/bin.2.fa
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metabat2: stub_version
    END_VERSIONS
    """
}
