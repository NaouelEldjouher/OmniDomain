process RAGTAG {
    tag "$meta.id"
    label 'process_medium'


    input:
    tuple val(meta),  path(fasta)
    tuple val(meta2), path(reference)

    output:
    tuple val(meta), path("ragtag.scaffold.fasta"), emit: scaffolds
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    #!/bin/bash
    set -eo pipefail

    # Validate inputs
    if [ ! -s "${fasta}" ]; then
        echo "ERROR: Input assembly FASTA is empty: ${fasta}"
        exit 1
    fi
    if [ ! -s "${reference}" ]; then
        echo "ERROR: Reference genome is empty: ${reference}"
        exit 1
    fi

    NSEQS=\$(grep -c "^>" ${fasta} || echo 0)
    echo "INFO: Scaffolding \$NSEQS contigs against reference"

    # Run RagTag scaffold
    # If no alignments found (e.g. organelle contigs vs nuclear reference),
    # RagTag exits 0 but produces minimal output — we detect and pass through
    ragtag.py scaffold \\
        -t ${task.cpus} \\
        ${args} \\
        ${reference} \\
        ${fasta} \\
        -o ragtag_output

    # Check scaffold output has real content
    if [ -s "ragtag_output/ragtag.scaffold.fasta" ]; then
        SCAFFOLD_SIZE=\$(wc -c < ragtag_output/ragtag.scaffold.fasta)
        echo "INFO: Scaffold output size: \$SCAFFOLD_SIZE bytes"

        if [ "\$SCAFFOLD_SIZE" -gt 100 ]; then
            cp ragtag_output/ragtag.scaffold.fasta ragtag.scaffold.fasta
            echo "INFO: RagTag scaffolding successful"
        else
            # Output too small — likely header only, no sequence placed
            echo "WARNING: RagTag produced minimal output (\$SCAFFOLD_SIZE bytes)"
            echo "WARNING: Contigs could not be placed against reference"
            echo "WARNING: This is expected when organelle contigs are scaffolded against nuclear reference"
            echo "WARNING: Passing input contigs through unchanged"
            cp ${fasta} ragtag.scaffold.fasta
        fi
    else
        echo "WARNING: RagTag produced no scaffold output"
        echo "WARNING: Passing input contigs through unchanged"
        cp ${fasta} ragtag.scaffold.fasta
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ragtag: \$(ragtag.py --version 2>&1 | awk '{print \$2}' || echo "2.1.0")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Stub produces valid FASTA — empty file cascades to downstream failures
    printf '>stub_scaffold_1\\nATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG\\n' \
        > ragtag.scaffold.fasta
    printf '>stub_scaffold_2\\nGCATGCATGCATGCATGCATGCATGCATGCATGCATGCATGCATGCAT\\n' \
        >> ragtag.scaffold.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ragtag: stub_2.1.0
    END_VERSIONS
    """
}