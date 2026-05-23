// Replaced MAKER with BRAKER3 for dfam independence
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

# ... Augustus config setup ...

if [ -n "${proteins}" ] && [ -s "${proteins}" ]; then
if [[ "${proteins}" == *.gz ]]; then
gunzip -c ${proteins} > proteins_input.faa
else
cp ${proteins} proteins_input.faa
fi
PROT_ARG="--prot_seq=proteins_input.faa"
else
echo "INFO: No protein hints — BRAKER3 ab initio mode"
PROT_ARG=""
fi

braker.pl \\
--genome=${fasta} \\
\${PROT_ARG} \\          ← escaped — bash evaluates this, not Groovy
--softmasking \\
--threads=${task.cpus} \\
--workingdir=braker \\
--AUGUSTUS_CONFIG_PATH=\$AUGUSTUS_CONFIG_PATH \\
${args}
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