process REPEATMODELER {
    tag "$meta.id"
    label 'process_high'

    container "${ workflow.containerEngine in ['singularity', 'apptainer'] ?
        'https://depot.galaxyproject.org/singularity/repeatmodeler:2.0.5--pl5321hdfd78af_0' :
        'quay.io/biocontainers/repeatmodeler:2.0.5--pl5321hdfd78af_0' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*-families.fa"), emit: repeat_library
    path "versions.yml"                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args   = task.ext.args   ?: ''
    """
    #!/bin/bash
    set -eo pipefail

    # Validate input — fail fast with clear message
    if [ ! -s "${fasta}" ]; then
        echo "ERROR: Input assembly FASTA is empty: ${fasta}"
        echo "ERROR: Check upstream GFA_TO_FASTA and scaffolding outputs"
        exit 1
    fi

    # GFA conversion safety — should not be needed after GFA_TO_FASTA upstream
    # Kept as defensive fallback only
    INPUT_FASTA="${fasta}"
    if [[ "${fasta.name}" == *.gfa ]]; then
        echo "WARNING: Received GFA input — GFA_TO_FASTA should run first"
        awk '/^S/ {print ">"\$2; print \$3}' ${fasta} > ${prefix}_input.fasta
        INPUT_FASTA=${prefix}_input.fasta
    fi

    SEQ_LEN=\$(awk '/^>/ {next} {s+=length(\$0)} END {print s+0}' \$INPUT_FASTA)
    echo "INFO: Input sequence length: \$SEQ_LEN bp"

    if [ "\$SEQ_LEN" -gt 10000 ]; then
        # Build BLAST database and run RepeatModeler
        BuildDatabase -name ${prefix}_db \$INPUT_FASTA
        RepeatModeler \\
            -database ${prefix}_db \\
            -threads ${task.cpus} \\
            ${args}
        mv ${prefix}_db-families.fa ${prefix}-families.fa
    else
        # Sequence too small for RepeatModeler (organelle fragments, test data)
        # Emit minimal valid repeat library so RepeatMasker can still run
        echo "WARNING: Sequence too small (\$SEQ_LEN bp) for RepeatModeler"
        echo "WARNING: Emitting minimal repeat library — masking will be minimal"
        printf '>minimal_repeat#Unknown\\nATGCATGCATGCATGCATGC\\n' > ${prefix}-families.fa
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        repeatmodeler: \$(RepeatModeler -v 2>&1 | awk '{print \$NF}' || echo "2.0.5")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Stub produces minimal valid repeat library
    # Empty library causes RepeatMasker to fail — must have at least one entry
    printf '>stub_repeat#DNA\\nATGCATGCATGCATGCATGCATGCATGCATGCATGCATGCATGCATGC\\n' \
        > ${prefix}-families.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        repeatmodeler: stub_2.0.5
    END_VERSIONS
    """
}