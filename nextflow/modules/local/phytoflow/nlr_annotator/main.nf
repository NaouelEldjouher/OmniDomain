process NLR_ANNOTATOR {
    tag "$meta.id"
    label 'process_medium'

    // Eclipse Temurin JRE 11 — NLR-Annotator requires Java 11+
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-ec60f6e2b2f23fbbd88cf5dc98df3fb7a4b67abd:b4e67c1c944b5b83af77d0c94e86671e11a4eae3-0' :
        'eclipse-temurin:11-jre-jammy' }"

    input:
    tuple val(meta), path(scaffolds), path(nlr_jar), path(nlr_mot), path(nlr_store)

    output:
    tuple val(meta), path("*.nlr.txt"), emit: results
    path "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args   = task.ext.args   ?: ''
    """
    #!/bin/bash
    set -eo pipefail

    # Validate inputs
    if [ ! -s "${scaffolds}" ]; then
        echo "ERROR: Input scaffold FASTA is empty: ${scaffolds}"
        exit 1
    fi
    if [ ! -f "${nlr_jar}" ]; then
        echo "ERROR: NLR-Annotator JAR not found: ${nlr_jar}"
        exit 1
    fi

    # GFA conversion safety — should not be needed after GFA_TO_FASTA upstream
    INPUT_FASTA="${scaffolds}"
    if [[ "${scaffolds.name}" == *.gfa ]]; then
        echo "WARNING: Received GFA — GFA_TO_FASTA should run first"
        awk '/^S/ {print ">"\$2; print \$3}' ${scaffolds} > ${prefix}_input.fasta
        INPUT_FASTA=${prefix}_input.fasta
    fi

    NSEQS=\$(grep -c "^>" \$INPUT_FASTA || echo 0)
    SEQ_LEN=\$(awk '/^>/ {next} {s+=length(\$0)} END {print s+0}' \$INPUT_FASTA)
    echo "INFO: Running NLR-Annotator on \$NSEQS sequences (\$SEQ_LEN bp)"

    if [ "\$SEQ_LEN" -gt 5000 ]; then
        java -jar ${nlr_jar} \\
            -i \$INPUT_FASTA \\
            -x ${nlr_mot} \\
            -y ${nlr_store} \\
            -o ${prefix}.nlr.txt \\
            -t ${task.cpus} \\
            ${args}

        # Count identified NLR loci
        NNLR=\$(grep -c "." ${prefix}.nlr.txt 2>/dev/null || echo 0)
        echo "INFO: NLR-Annotator identified \$NNLR candidate loci"
        echo "INFO: 0 results expected for organelle assemblies — nuclear R genes only"
    else
        echo "WARNING: Sequence too small (\$SEQ_LEN bp) for NLR motif search"
        echo "No NLR motifs found — sequence below minimum threshold." > ${prefix}.nlr.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nlr_annotator: "2.1b"
        java: \$(java -version 2>&1 | head -1 | grep -oP '"[\\d._]+"' | tr -d '"' || echo "11")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Stub produces valid NLR output format
    # Empty file causes downstream parsing errors
    cat > ${prefix}.nlr.txt << 'NLR'
# NLR-Annotator v2.1b stub output
# Column: sequence_id, start, end, strand, type, motif_string
# No NLR loci identified in stub sequence
NLR

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nlr_annotator: "2.1b"
        java: "11"
    END_VERSIONS
    """
}
