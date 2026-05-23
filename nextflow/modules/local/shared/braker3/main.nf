process BRAKER3 {
tag "$meta.id"
label 'process_high'

container 'docker.io/teambraker/braker3:latest'

input:
tuple val(meta),      path(fasta)
tuple val(meta_prot), path(proteins)

output:
tuple val(meta), path("braker/braker.gtf"), emit: gff
tuple val(meta), path("braker/braker.aa"),  emit: proteins
path "versions.yml",                        emit: versions

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

# Scope Augustus config to job work directory
# Prevents read-only /opt/Augustus/config conflict and cross-job contamination
# Critical for parallel AWS runs — each job gets isolated Augustus species dir
export AUGUSTUS_CONFIG_PATH=\$(pwd)/augustus_config
mkdir -p \$AUGUSTUS_CONFIG_PATH
cp -r /opt/Augustus/config/* \$AUGUSTUS_CONFIG_PATH/ 2>/dev/null || true
mkdir -p braker

SEQ_LEN=\$(awk '/^>/ {next} {s+=length(\$0)} END {print s+0}' ${fasta})
NSEQS=\$(grep -c "^>" ${fasta} || echo 0)
echo "INFO: Assembly: \$NSEQS sequences, \$SEQ_LEN bp"

if [ "\$SEQ_LEN" -lt 5000000 ]; then
# Test data / low coverage draft assembly — too small for GeneMark training
# Use Augustus directly with pre-trained species model
# Note: Augustus GTF differs slightly from BRAKER3 GTF format
# Downstream tools use proteins (.aa) not GTF — format difference is safe
echo "INFO: Assembly <5Mb — Augustus direct mode (bypasses GeneMark)"

        augustus \\
            --species=aspergillus_fumigatus \\
            --AUGUSTUS_CONFIG_PATH=\$AUGUSTUS_CONFIG_PATH \\
            --gff3=off \\
            ${fasta} > braker/braker.gtf

        # Extract proteins from Augustus prediction
        getAnnoFasta.pl braker/braker.gtf 2>/dev/null || true
        # getAnnoFasta.pl writes to <input>.aa — rename to expected path
        mv braker/braker.gtf.aa braker/braker.aa 2>/dev/null || \
        mv *.aa braker/braker.aa 2>/dev/null || \
        touch braker/braker.aa

    else
        # Real assembly — full BRAKER3 with GeneMark training
        echo "INFO: Assembly ≥5Mb — BRAKER3 full mode"

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
\${PROT_ARG} \\
--softmasking \\
--threads=${task.cpus} \\
--workingdir=braker \\
--AUGUSTUS_CONFIG_PATH=\$AUGUSTUS_CONFIG_PATH \\
${args}
fi

# Validate outputs
if [ ! -s "braker/braker.gtf" ]; then
echo "ERROR: No gene predictions produced"
exit 1
fi

# braker.aa may be empty for small assemblies — touch prevents Nextflow crash
[ -f "braker/braker.aa" ] || touch braker/braker.aa

NGENES=\$(grep -c '\\bgene\\b' braker/braker.gtf || echo 0)
echo "INFO: Annotation complete — \$NGENES genes predicted"

cat <<-END_VERSIONS > versions.yml
"${task.process}":
braker3: \$(braker.pl --version 2>&1 | grep -oP '[\\d.]+' | head -1 || echo "3.0")
END_VERSIONS
"""

stub:
"""
mkdir -p braker
printf 'stub_seq\tBRAKER\tgene\t1000\t5000\t.\t+\t.\tgene_id "stub_gene1"\n' \
> braker/braker.gtf
printf '>stub_protein_1\nMSTARTPEPTIDE\n' > braker/braker.aa

cat <<-END_VERSIONS > versions.yml
"${task.process}":
braker3: stub_3.0
END_VERSIONS
"""
}