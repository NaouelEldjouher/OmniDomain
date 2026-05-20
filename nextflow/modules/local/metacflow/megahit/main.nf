process MEGAHIT {
    tag "$meta.id"
    label 'process_high'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("megahit_out/${meta.id}.contigs.fa"), emit: contigs
    path "versions.yml"                                      , emit: versions

    script:
    def prefix = "${meta.id}"
    def input_reads = reads.size() == 2 ? "-1 ${reads[0]} -2 ${reads[1]}" : "-r ${reads}"
    """
    megahit \\
        $input_reads \\
        -t $task.cpus \\
        -o megahit_out \\
        --out-prefix $prefix

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        megahit: \$(megahit --version 2>&1 | grep -oE "[0-9.]+")
    END_VERSIONS
    """

    stub:
    def prefix = "${meta.id}"
    """
    mkdir -p megahit_out
    touch megahit_out/${prefix}.contigs.fa
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        megahit: stub_version
    END_VERSIONS
    """
}
