process DBCAN {
tag "$meta.id"
label 'process_medium'

container 'quay.io/biocontainers/dbcan:4.1.4--pyhdfd78af_0'

input:
tuple val(meta), path(proteins)

output:
tuple val(meta), path("*.overview.txt"), emit: overview
path "versions.yml",                     emit: versions

when:
task.ext.when == null || task.ext.when

script:
def prefix = task.ext.prefix ?: "${meta.id}"  // ← was missing from script block
def args   = task.ext.args   ?: ''
"""
#!/bin/bash
set -eo pipefail

if [ ! -s "${proteins}" ]; then
echo "WARNING: Empty protein file — skipping dbCAN"
touch ${prefix}.overview.txt
else
NPROTEINS=\$(grep -c "^>" ${proteins} || echo 0)
echo "INFO: Running dbCAN on \$NPROTEINS proteins"

run_dbcan ${proteins} protein \\
--out_dir ${prefix}_dbcan \\
--db_dir /db \\
${args}

mv ${prefix}_dbcan/overview.txt ${prefix}.overview.txt

NCAZYMES=\$(tail -n +2 ${prefix}.overview.txt | wc -l || echo 0)
echo "INFO: \$NCAZYMES CAZyme annotations found"
fi

cat <<-END_VERSIONS > versions.yml
"${task.process}":
dbcan: \$(run_dbcan --version 2>&1 | head -1 || echo "4.1.4")
END_VERSIONS
"""

stub:
def prefix = task.ext.prefix ?: "${meta.id}"
"""
printf 'Gene ID\tEC#\tHMMER\tdiamond\tSignalP\t#ofTools\n' \
> ${prefix}.overview.txt
printf 'stub_protein_1\t-\tGH18\tGH18\tN\t2\n' \
>> ${prefix}.overview.txt

cat <<-END_VERSIONS > versions.yml
"${task.process}":
dbcan: stub_4.1.4
END_VERSIONS
"""
}