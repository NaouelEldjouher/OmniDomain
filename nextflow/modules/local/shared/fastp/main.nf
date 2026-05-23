process FASTP {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine in ['singularity', 'apptainer'] ?
        'https://depot.galaxyproject.org/singularity/fastp:0.23.4--hadf994f_2' :
        'quay.io/biocontainers/fastp:0.23.4--hadf994f_2' }"

    input:
    tuple val(meta), path(reads)
    val   adapter_fasta
    val   save_trimmed_fail
    val   save_merged

    output:
    tuple val(meta), path('*.fastp.fastq.gz') , emit: reads
    tuple val(meta), path('*.json')            , emit: json
    tuple val(meta), path('*.html')            , emit: html
    tuple val(meta), path('*.log')             , emit: log
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix   = task.ext.prefix ?: "${meta.id}"
    def args     = task.ext.args   ?: ''
    def paired   = meta.single_end ? "" : "--in2 ${reads[1]} --out2 ${prefix}_2.fastp.fastq.gz"
    def input1   = meta.single_end ? reads : reads[0]
    def output1  = "${prefix}_1.fastp.fastq.gz"
    """
    fastp \\
        --in1 ${input1} \\
        ${paired} \\
        --out1 ${output1} \\
        --json ${prefix}.fastp.json \\
        --html ${prefix}.fastp.html \\
        --thread ${task.cpus} \\
        ${args} \\
        2> ${prefix}.fastp.log
    echo '"${task.process}":' > versions.yml
    echo "    fastp: \$(fastp --version 2>&1 | sed -e 's/fastp //')" >> versions.yml
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf '@stub\nACGT\n+\nIIII\n' | gzip > ${prefix}_1.fastp.fastq.gz
    touch ${prefix}.fastp.json
    touch ${prefix}.fastp.html
    touch ${prefix}.fastp.log
    echo '"${task.process}":' > versions.yml
    echo '    fastp: stub_0.23.4' >> versions.yml
    """
}
