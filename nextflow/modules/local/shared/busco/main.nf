process BUSCO {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine in ['singularity', 'apptainer'] ?
        'https://depot.galaxyproject.org/singularity/busco:5.8.0_cv1' :
        'ezlabgva/busco:v5.8.0_cv1' }"

    input:
    tuple val(meta), path(fasta)
    val mode     // 'genome', 'transcriptome', or 'proteins'
    val lineage  // e.g., 'embryophyta_odb10', 'fungi_odb10'

    output:
    tuple val(meta), path("busco_out/short_summary.*.txt"), emit: short_txt
    tuple val(meta), path("busco_out/")                  , emit: full_dir
    path "versions.yml"                                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    #!/bin/bash
    set -eo pipefail

    # Validate input — fail fast with clear message
    if [ ! -s "${fasta}" ]; then
        echo "ERROR: Input FASTA is empty: ${fasta}"
        echo "ERROR: Check upstream GFA_TO_FASTA and RepeatMasker outputs"
        exit 1
    fi

    NSEQS=\$(grep -c "^>" ${fasta} || echo 0)
    echo "INFO: Running BUSCO on \$NSEQS sequences"
    echo "INFO: Mode: ${mode} | Lineage: ${lineage}"

    # Run BUSCO
    # --offline prevents database download attempts on restricted networks
    # Remove --offline if lineage database is not pre-downloaded
    busco \\
        -i ${fasta} \\
        -l ${lineage} \\
        -o busco_out \\
        -m ${mode} \\
        -c ${task.cpus} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: \$(busco --version 2>&1 | sed 's/BUSCO //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p busco_out/run_${lineage}/

    # Stub produces valid BUSCO summary format
    # Matches real output structure so downstream parsers don't crash
    cat <<-SUMMARY > busco_out/short_summary.specific.${lineage}.busco_out.txt
    # BUSCO version is: 5.8.0
    # The lineage dataset is: ${lineage}
    # BUSCO was run in mode: ${mode}
        ***** Results: *****
        C:0.0%[S:0.0%,D:0.0%],F:0.0%,M:100.0%,n:1614
        0\tComplete BUSCOs (C)
        0\tComplete and single-copy BUSCOs (S)
        0\tComplete and duplicated BUSCOs (D)
        0\tFragmented BUSCOs (F)
        1614\tMissing BUSCOs (M)
        1614\tTotal BUSCO groups searched
    Assembly Statistics:
        7\tNumber of scaffolds
        7\tNumber of contigs
        845847\tTotal length
        0.000%\tPercent gaps
        146 KB\tScaffold N50
        146 KB\tContigs N50
    SUMMARY

    touch busco_out/run_${lineage}/full_table.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: stub_5.8.0
    END_VERSIONS
    """
}
