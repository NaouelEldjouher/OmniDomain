// modules/local/fungalflow/phobius/main.nf

process PHOBIUS {
tag "$meta.id"
label 'process_low'

container 'quay.io/biocontainers/phobius:101--hdfd78af_3'

input:
tuple val(meta), path(proteins)

output:
tuple val(meta), path("*.phobius.txt"), emit: results
path "versions.yml",                    emit: versions

when:
task.ext.when == null || task.ext.when

script:
def prefix = task.ext.prefix ?: "${meta.id}"
"""
#!/bin/bash
set -eo pipefail

if [ ! -s "${proteins}" ]; then
echo "WARNING: Empty protein file — skipping secretome prediction"
touch ${prefix}.phobius.txt
else
NPROTEINS=\$(grep -c "^>" ${proteins} || echo 0)
echo "INFO: Running Phobius on \$NPROTEINS proteins"

phobius.pl -short ${proteins} > ${prefix}.phobius.txt

# Count secreted proteins (SP=YES, TM=0)
SECRETED=\$(awk '\$2=="SP" && \$3==0' ${prefix}.phobius.txt | wc -l || echo 0)
echo "INFO: \$SECRETED secreted proteins predicted"
fi

cat <<-END_VERSIONS > versions.yml
"${task.process}":
phobius: \$(phobius.pl --version 2>&1 | grep -oP '[\\d.]+' | head -1 || echo "101")
END_VERSIONS
"""

stub:
def prefix = task.ext.prefix ?: "${meta.id}"
"""
printf 'SEQID\\tSP\\tTM\\tPREDICTION\\n' > ${prefix}.phobius.txt
printf 'stub_protein_1\\tSP\\t0\\tSecretory\\n' >> ${prefix}.phobius.txt
printf 'stub_protein_2\\t0\\t2\\tTransmembrane\\n' >> ${prefix}.phobius.txt

cat <<-END_VERSIONS > versions.yml
"${task.process}":
phobius: stub_101
END_VERSIONS
"""
}