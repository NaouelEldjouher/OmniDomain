// modules/local/extract_proteome/main.nf
// Extracts predicted protein sequences from genome assembly + GFF annotation
// Tool: AGAT (Another Gff Analysis Toolkit) — handles all GFF flavours correctly

process EXTRACT_PROTEOME {
    tag "$meta.id"
    label 'process_low'



    input:
    tuple val(meta), path(fasta), path(gff)

    output:
    tuple val(meta), path("${meta.id}_proteins.fasta"), emit: proteome
    path "versions.yml"                               , emit: versions

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
    if [ ! -s "${gff}" ]; then
        echo "WARNING: Input GFF is empty: ${gff}"
        echo "WARNING: No gene models available — creating empty protein FASTA"
        touch ${prefix}_proteins.fasta
    else
        NGENES=\$(grep -c "\\bgene\\b" ${gff} 2>/dev/null || echo 0)
        echo "INFO: Extracting proteins from \$NGENES gene models"

        # -p flag: extract protein sequences (translate CDS)
        # AGAT handles GFF2/GFF3/GTF and fixes common format issues automatically
        agat_sp_extract_sequences.pl \\
            -g ${gff} \\
            -f ${fasta} \\
            -p \\
            -o ${prefix}_proteins.fasta \\
            ${args}

        NPROTEINS=\$(grep -c "^>" ${prefix}_proteins.fasta 2>/dev/null || echo 0)
        echo "INFO: Extracted \$NPROTEINS protein sequences"
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        agat: \$(agat_sp_extract_sequences.pl --version 2>&1 | grep -oP 'v[\\d.]+' | head -1 || echo "1.4.0")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Stub produces minimal valid protein FASTA
    # Empty file causes eggNOG and PlantTFDB to fail silently
    printf '>stub_protein_1 gene=stub_gene1\\nMSTARTPEPTIDESTUBSEQUENCEFORTESTING*\\n' \
        > ${prefix}_proteins.fasta
    printf '>stub_protein_2 gene=stub_gene2\\nMANOTHERSTUBPROTEINSEQUENCEFORTEST*\\n' \
        >> ${prefix}_proteins.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        agat: stub_1.4.0
    END_VERSIONS
    """
}
