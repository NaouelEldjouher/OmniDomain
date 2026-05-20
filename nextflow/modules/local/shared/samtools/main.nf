// modules/local/samtools/main.nf

process SAMTOOLS_COVERAGE {
    tag "$meta.id"
    label 'process_low'

    container "${ workflow.containerEngine in ['singularity', 'apptainer'] ?
        'https://depot.galaxyproject.org/singularity/samtools:1.21--h50ea8bc_0' :
        'staphb/samtools:1.21' }"

    input:
    tuple val(meta), path(sam)

    output:
    tuple val(meta), path("*.coverage.txt"), emit: coverage
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args   = task.ext.args   ?: ''
    """
    #!/bin/bash
    set -eo pipefail

    # Validate SAM input is not empty
    if [ ! -s "${sam}" ]; then
        echo "ERROR: Input SAM file is empty: ${sam}"
        exit 1
    fi

    # Sort SAM → BAM (required by samtools coverage)
    samtools sort \\
        -@ ${task.cpus} \\
        -o ${prefix}.sorted.bam \\
        ${sam}

    # Index BAM for random access
    samtools index ${prefix}.sorted.bam

    # Calculate per-contig coverage statistics
    # Output columns: rname, startpos, endpos, numreads, covbases,
    #                 coverage%, meandepth, meanbaseq, meanmapq
    samtools coverage \\
        ${args} \\
        ${prefix}.sorted.bam > ${prefix}.coverage.txt

    # Print summary to log for immediate visibility
    echo "=== Coverage Summary: ${meta.id} ==="
    cat ${prefix}.coverage.txt

    # Clean up intermediate BAM — only coverage report needed downstream
    rm -f ${prefix}.sorted.bam ${prefix}.sorted.bam.bai

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version 2>&1 | head -1 | sed 's/samtools //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Stub produces valid coverage TSV with realistic organelle values
    # chloroplast ~400x, mitochondrion ~90x
    printf '#rname\tstartpos\tendpos\tnumreads\tcovbases\tcoverage\tmeandepth\tmeanbaseq\tmeanmapq\n' \
        > ${prefix}.coverage.txt
    printf 'ptg000001l\t1\t282616\t2055\t282616\t100.00\t88.69\t255\t53.9\n' \
        >> ${prefix}.coverage.txt
    printf 'ptg000003l\t1\t155667\t28901\t155667\t100.00\t412.60\t255\t40.1\n' \
        >> ${prefix}.coverage.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: stub_1.21
    END_VERSIONS
    """
}
