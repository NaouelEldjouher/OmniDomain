process DEEPSIG {
tag "$meta.id"
label 'process_low'

// Open source — no license required
// Savojardo et al. 2018, Bioinformatics 34(10):1690-1696
// Container entrypoint is /usr/src/deepsig/deepsig.py
// Override entrypoint in modules.config: containerOptions = '--entrypoint ""'
container 'bolognabiocomp/deepsig'

input:
tuple val(meta), path(proteins)

output:
tuple val(meta), path("*.deepsig.gff3"), emit: results
tuple val(meta), path("*.secreted.faa"), emit: secreted
path "versions.yml",                     emit: versions

when:
task.ext.when == null || task.ext.when

script:
def prefix = task.ext.prefix ?: "${meta.id}"
def args   = task.ext.args   ?: ''
"""
#!/bin/bash
set -eo pipefail

if [ ! -s "${proteins}" ]; then
echo "WARNING: Empty protein file — skipping DeepSig"
touch ${prefix}.deepsig.gff3
touch ${prefix}.secreted.faa
else
# Decompress if needed — DeepSig requires uncompressed FASTA
if [[ "${proteins}" == *.gz ]]; then
gunzip -c ${proteins} > proteins_input.faa
else
cp ${proteins} proteins_input.faa
fi

NPROTEINS=\$(grep -c "^>" proteins_input.faa || true)
echo "INFO: Running DeepSig on \$NPROTEINS proteins (eukaryote mode)"

# Full path — entrypoint overridden via containerOptions
/usr/src/deepsig/deepsig.py \\
-f proteins_input.faa \\
-o ${prefix}.deepsig.gff3 \\
-k euk \\
${args}

# Extract IDs of proteins with signal peptide
grep "Signal peptide" ${prefix}.deepsig.gff3 \\
| awk '{print \$1}' \\
| sort -u > secreted_ids.txt || true

NSECR=\$(wc -l < secreted_ids.txt || true)
echo "INFO: \$NSECR proteins predicted as secreted"

# Write secreted protein FASTA
if [ -s secreted_ids.txt ]; then
awk 'NR==FNR { ids[\$1]=1; next }
/^>/   { id=substr(\$1,2); keep=(id in ids)?1:0 }
keep   { print }
' secreted_ids.txt proteins_input.faa > ${prefix}.secreted.faa

NOUT=\$(grep -c "^>" ${prefix}.secreted.faa || true)
echo "INFO: \$NOUT secreted sequences written to ${prefix}.secreted.faa"
else
echo "INFO: No secreted proteins predicted"
touch ${prefix}.secreted.faa
fi
fi

# Version — DeepSig has no --version flag, read from package metadata
DEEPSIG_VER=\$(python3 -c "import pkg_resources; print(pkg_resources.get_distribution('deepsig-biocomp').version)" 2>/dev/null || echo "1.2.5")

cat <<-END_VERSIONS > versions.yml
"${task.process}":
deepsig: \$DEEPSIG_VER
END_VERSIONS
"""

stub:
def prefix = task.ext.prefix ?: "${meta.id}"
"""
printf '##gff-version 3\n'                                                      > ${prefix}.deepsig.gff3
printf 'stub_p1\tDeepSig\tSignal peptide\t1\t20\t0.98\t.\t.\tevidence=ECO:0000256\n' >> ${prefix}.deepsig.gff3
printf 'stub_p1\tDeepSig\tChain\t21\t350\t.\t.\t.\tevidence=ECO:0000256\n'     >> ${prefix}.deepsig.gff3
printf 'stub_p2\tDeepSig\tChain\t1\t420\t.\t.\t.\tevidence=ECO:0000256\n'      >> ${prefix}.deepsig.gff3

printf '>stub_p1\nMKLLVVALLVAFCSGVQASEKLDE\n' > ${prefix}.secreted.faa

cat <<-END_VERSIONS > versions.yml
"${task.process}":
deepsig: stub_1.2.5
END_VERSIONS
"""
}