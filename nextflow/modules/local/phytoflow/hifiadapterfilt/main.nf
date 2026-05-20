process HIFIADAPTERFILT {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine in ['singularity', 'apptainer'] ?
        'https://depot.galaxyproject.org/singularity/hifiadapterfilt:3.0.0--hdfd78af_0' :
        'quay.io/biocontainers/hifiadapterfilt:3.0.0--hdfd78af_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.filt.fastq.gz"), emit: reads
    path "*.stats"                          , emit: stats
    path "*.blocklist"                      , emit: blocklist
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args   = task.ext.args   ?: ''
    """
    # Run hifiadapterfilt — tool names output based on input filename
    hifiadapterfilt.sh \\
        -t ${task.cpus} \\
        ${args} \\
        ${reads}

    # Rename outputs to match Nextflow expected pattern
    # Tool produces <input_basename>.fastq.gz — rename to <prefix>.filt.fastq.gz
    INPUT_BASE=\$(basename ${reads} .fastq.gz)
    if [ -f "\${INPUT_BASE}.fastq.gz" ]; then
        mv "\${INPUT_BASE}.fastq.gz" "${prefix}.filt.fastq.gz"
    fi
    if [ -f "\${INPUT_BASE}.stats" ]; then
        mv "\${INPUT_BASE}.stats" "${prefix}.stats"
    else
        touch "${prefix}.stats"
    fi
    if [ -f "\${INPUT_BASE}.blocklist" ]; then
        mv "\${INPUT_BASE}.blocklist" "${prefix}.blocklist"
    else
        touch "${prefix}.blocklist"
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hifiadapterfilt: \$(hifiadapterfilt.sh --version 2>&1 | grep -oP '\\d+\\.\\d+\\.\\d+' | head -1 || echo "3.0.0")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Stub produces minimal valid FASTQ — empty file causes cascade failures
    printf '@stub_read_1\\nATCGATCGATCGATCGATCGATCGATCGATCG\\n+\\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\\n' \\
        | gzip > ${prefix}.filt.fastq.gz
    echo "stub stats"     > ${prefix}.stats
    echo "stub blocklist" > ${prefix}.blocklist

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hifiadapterfilt: 3.0.0
    END_VERSIONS
    """
}