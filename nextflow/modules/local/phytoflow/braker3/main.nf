process BRAKER3 {
    tag "$meta.id"
    label 'process_high'

    container 'docker.io/teambraker/braker3:latest'

    input:
    tuple val(meta),      path(fasta)
    tuple val(meta_prot), path(proteins)

    output:
    tuple val(meta), path("braker/braker.gtf"),  emit: gff      // ← gtf not gff3
    tuple val(meta), path("braker/braker.aa"),   emit: proteins  // bonus — predicted proteins
    path "versions.yml",                          emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix   = task.ext.prefix ?: "${meta.id}"
    def args     = task.ext.args   ?: ''
    def prot_arg = proteins ? "--prot_seq=proteins_input.faa" : ''
    """
    #!/bin/bash
    set -eo pipefail

    if [ ! -s "${fasta}" ]; then
        echo "ERROR: Input FASTA is empty"
        exit 1
    fi

    # Decompress proteins if gzipped
    if [[ "${proteins}" == *.gz ]]; then
        gunzip -c ${proteins} > proteins_input.faa
    else
        cp ${proteins} proteins_input.faa
    fi

    NSEQS=\$(grep -c "^>" ${fasta} || echo 0)
    echo "INFO: Running BRAKER3 on \$NSEQS sequences"

    braker.pl \\
        --genome=${fasta} \\
        ${prot_arg} \\
        --softmasking \\
        --threads=${task.cpus} \\
        --workingdir=braker \\
        ${args}

    echo "INFO: BRAKER3 complete"
    echo "INFO: Genes predicted: \$(grep -c '\\bgene\\b' braker/braker.gtf || echo 0)"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        braker3: \$(braker.pl --version 2>&1 | grep -oP '[\\d.]+' | head -1 || echo "3.0")
    END_VERSIONS
    """

    stub:
    """
    mkdir -p braker
    cat > braker/braker.gtf << 'GTF'
# BRAKER3 stub output
stub_seq\tBRAKER\tgene\t1000\t5000\t.\t+\t.\tgene_id "stub_gene1"
stub_seq\tBRAKER\ttranscript\t1000\t5000\t.\t+\t.\tgene_id "stub_gene1"; transcript_id "stub_t1"
stub_seq\tBRAKER\tCDS\t1100\t4900\t.\t+\t0\tgene_id "stub_gene1"; transcript_id "stub_t1"
GTF
    printf '>stub_protein_1\\nMSTARTPEPTIDE*\\n' > braker/braker.aa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        braker3: stub_3.0
    END_VERSIONS
    """
}