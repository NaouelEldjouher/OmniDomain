process NANOPLOT {
    tag "$meta.id"
    label 'process_low'

    container 'quay.io/biocontainers/nanoplot:1.42.0--pyhdfd78af_0'

    input:
    tuple val(meta), path(ontfile)

    output:
    tuple val(meta), path("*.html")                , emit: html
    tuple val(meta), path("*.png") , optional: true, emit: png
    tuple val(meta), path("*.txt")                 , emit: txt
    tuple val(meta), path("*.log")                 , emit: log
    path "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args  = task.ext.args ?: ''
    def input = ontfile.collect { "--fastq $it" }.join(' ')
    """
    NanoPlot \\
        $args \\
        -t $task.cpus \\
        $input
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(NanoPlot --version 2>&1 | sed -e "s/NanoPlot //g")
    END_VERSIONS
    """

    stub:
    """
    touch NanoPlot-report.html
    touch NanoStats.txt
    touch NanoPlot.log
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: stub_1.42.0
    END_VERSIONS
    """
}
