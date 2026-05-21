
process BRAKER3 {
    tag "$meta.id"
    label 'process_high'

    container 'docker.io/teambraker/braker3:latest'

    input:
    tuple val(meta),      path(fasta)
    tuple val(meta_prot), path(proteins)

    output:
    tuple val(meta), path("braker/braker.gtf"),  emit: gff      // ← gtf not gff3
    tuple val(meta), path("braker/braker.aa"),   emit: proteins
    path "versions.yml",                          emit: versions

    when:
    task.ext.when == null || task.ext.when

script:
def prefix = task.ext.prefix ?: "${meta.id}"
def args   = task.ext.args   ?: ''
"""
#!/bin/bash
set -eo pipefail

if [ ! -s "${fasta}" ]; then
echo "ERROR: Input FASTA is empty"
exit 1
fi

# ── Scope Augustus config to work directory ───────────────────────────────
# BRAKER3 writes species models to AUGUSTUS_CONFIG_PATH/species/
# Default path /opt/Augustus/config/species is read-only — BRAKER3 copies
# to /home/jovyan/.augustus which persists and causes conflicts on rerun
# Fix: point Augustus config to a fresh per-job writable directory
export AUGUSTUS_CONFIG_PATH=\$(pwd)/augustus_config
mkdir -p \$AUGUSTUS_CONFIG_PATH
# Copy base Augustus config into job directory
cp -r /opt/Augustus/config/* \$AUGUSTUS_CONFIG_PATH/ 2>/dev/null || true

# ── Protein hints ─────────────────────────────────────────────────────────
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

SEQ_LEN=\$(awk '/^>/ {next} {s+=length(\$0)} END {print s+0}' ${fasta})
NSEQS=\$(grep -c "^>" ${fasta} || echo 0)
echo "INFO: Assembly: \$NSEQS sequences, \$SEQ_LEN bp"
echo "INFO: Augustus config: \$AUGUSTUS_CONFIG_PATH"

braker.pl \\
--genome=${fasta} \\
\${PROT_ARG} \\
--softmasking \\
--threads=${task.cpus} \\
--workingdir=braker \\
--AUGUSTUS_CONFIG_PATH=\$AUGUSTUS_CONFIG_PATH \\
${args}

if [ ! -f "braker/braker.gtf" ]; then
echo "ERROR: BRAKER3 did not produce braker.gtf"
exit 1
fi

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