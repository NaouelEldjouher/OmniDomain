process REPEATMASKER {
    tag "$meta.id"
    label 'process_medium'

    
    input:
    tuple val(meta), path(fasta), path(library)

    output:
    tuple val(meta), path("*.masked.fa"), emit: masked_fasta
    tuple val(meta), path("*.tbl")      , emit: summary_table
    path "versions.yml"                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args   = task.ext.args   ?: ''
    """
    #!/bin/bash
    set -eo pipefail

    # Validate inputs
    if [ ! -s "${fasta}" ]; then
        echo "ERROR: Input assembly FASTA is empty: ${fasta}"
        exit 1
    fi
    if [ ! -s "${library}" ]; then
        echo "ERROR: Repeat library is empty: ${library}"
        exit 1
    fi

    echo "INFO: Running RepeatMasker with custom library: ${library.name}"

    # -xsmall: soft-mask (lowercase) rather than hard-mask (N)
    # -lib:    use custom RepeatModeler library
    # -pa:     deprecated — use -threads or -pa based on version
    RepeatMasker \\
        -pa ${task.cpus} \\
        -lib ${library} \\
        -xsmall \\
        -dir . \\
        ${args} \\
        ${fasta}

    # ── Normalise output filenames ────────────────────────────────────────────
    # RepeatMasker names outputs based on input filename
    # Standardise to *.masked.fa for consistent downstream handling

    MASKED_FILE=\$(ls ${fasta}.masked 2>/dev/null || ls *.masked 2>/dev/null || echo "")

    if [ -n "\$MASKED_FILE" ] && [ -s "\$MASKED_FILE" ]; then
        mv "\$MASKED_FILE" "${prefix}.masked.fa"
        echo "INFO: Masked FASTA: ${prefix}.masked.fa"
    else
        # RepeatMasker copies input unchanged when no repeats found
        # (common for organelle sequences with minimal repeat content)
        echo "WARNING: No .masked output — copying input as masked FASTA"
        echo "WARNING: This is expected for organelle sequences (<5% repeat content)"
        cp ${fasta} ${prefix}.masked.fa
    fi

    # Ensure summary table exists — RepeatMasker may skip it on minimal input
    TBL_FILE=\$(ls ${fasta}.tbl 2>/dev/null || ls *.tbl 2>/dev/null || echo "")
    if [ -n "\$TBL_FILE" ] && [ -s "\$TBL_FILE" ]; then
        mv "\$TBL_FILE" "${prefix}.tbl"
    else
        echo "WARNING: No .tbl summary — creating empty table"
        printf '==================================================\\n' > ${prefix}.tbl
        printf 'file name: ${fasta}\\n' >> ${prefix}.tbl
        printf 'RepeatMasker: no repeats identified\\n' >> ${prefix}.tbl
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        repeatmasker: \$(RepeatMasker -v 2>&1 | head -1 | grep -oP '[\\d.]+' | head -1 || echo "4.1.5")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Stub produces valid masked FASTA — empty file cascades to Helixer crash
    printf '>stub_contig_1\\natcgatcgatcgatcgatcgatcgatcgatcgatcgatcgatcgatcg\\n' \
        > ${prefix}.masked.fa
    printf '>stub_contig_2\\ngcatgcatgcatgcatgcatgcatgcatgcatgcatgcatgcatgcat\\n' \
        >> ${prefix}.masked.fa

    # Note: lowercase = soft-masked sequence (correct RepeatMasker -xsmall output)

    printf '==================================================\\n' > ${prefix}.tbl
    printf 'file name: stub\\n'                                    >> ${prefix}.tbl
    printf 'sequences:       2\\n'                                 >> ${prefix}.tbl
    printf 'total length:    96 bp\\n'                             >> ${prefix}.tbl
    printf 'GC level:        50.00 %%\\n'                          >> ${prefix}.tbl
    printf 'bases masked:    96 bp ( 100.00 %%)\\n'                >> ${prefix}.tbl

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        repeatmasker: stub_4.1.5
    END_VERSIONS
    """
}
