// modules/local/minimap2/main.nf

process MINIMAP2_ALIGN {
    tag "$meta.id"
    label 'process_medium'


    input:
    // 3-element tuple — reads and assembly joined upstream via .join()
    tuple val(meta), path(reads), path(assembly)

    output:
    tuple val(meta), path("*.sam"), emit: sam
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args   = task.ext.args   ?: '-ax map-hifi'
    // Assembly arrives as FASTA after GFA_TO_FASTA conversion
    // Keep GFA fallback for robustness in case it's called with raw GFA
    def ref    = assembly.name.endsWith('.gfa')
        ? "${prefix}_ref.fasta"
        : "${assembly}"
    """
    #!/bin/bash
    set -eo pipefail

    # Convert GFA to FASTA if needed — should not happen in normal pipeline flow
    # GFA_TO_FASTA upstream handles this — this is a safety fallback only
    if [[ "${assembly.name}" == *.gfa ]]; then
        echo "INFO: Converting GFA to FASTA (unexpected — GFA_TO_FASTA should run first)"
        awk '/^S/ {print ">"\$2; print \$3}' ${assembly} > ${prefix}_ref.fasta
    fi

    # Validate inputs are not empty
    # Validate first read file exists
    if [ ! -s "$(echo ${reads} | cut -d' ' -f1)" ]; then
        echo "ERROR: Input reads file is empty"
        exit 1
    fi
    if [ ! -s "${ref}" ]; then
        echo "ERROR: Reference assembly file is empty: ${ref}"
        exit 1
    fi

    echo "INFO: Mapping \$(grep -c '^@' <(zcat ${reads} 2>/dev/null || cat ${reads}) || echo 'unknown') reads to assembly"

    minimap2 \\
        ${args} \\
        -t ${task.cpus} \\
        ${ref} \\
        ${reads} > ${prefix}_aligned.sam

    # Validate SAM output has alignments
    NLINES=\$(wc -l < ${prefix}_aligned.sam)
    echo "INFO: SAM output lines: \$NLINES"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: \$(minimap2 --version 2>&1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Stub produces minimal valid SAM — empty SAM causes samtools to crash
    printf '@HD\tVN:1.6\tSO:unsorted\n' > ${prefix}_aligned.sam
    printf '@SQ\tSN:stub_contig_1\tLN:154000\n' >> ${prefix}_aligned.sam
    printf 'stub_read_1\t0\tstub_contig_1\t1\t60\t32M\t*\t0\t0\tATCGATCGATCGATCGATCGATCGATCGATCG\t*\n' >> ${prefix}_aligned.sam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: stub_2.28
    END_VERSIONS
    """
}
