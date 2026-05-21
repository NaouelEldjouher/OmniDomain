// modules/local/fungalflow/antismash/main.nf

process ANTISMASH {
tag "$meta.id"
label 'process_high'

container 'docker.io/antismash/standalone:7.1.0'

input:
tuple val(meta), path(assembly)    // ← was path(gff), must match script variable

output:
tuple val(meta), path("antismash_out/"), emit: results
path "versions.yml",                     emit: versions

when:
task.ext.when == null || task.ext.when

script:
def prefix = task.ext.prefix ?: "${meta.id}"
def taxon  = task.ext.taxon  ?: 'fungi'
"""
#!/bin/bash
set -eo pipefail

if [ ! -s "${assembly}" ]; then
echo "ERROR: Assembly file is empty"
exit 1
fi

NCONTIGS=\$(grep -c "^>" ${assembly} || echo 0)
echo "INFO: Running antiSMASH on \$NCONTIGS contigs"

antismash \\
--taxon ${taxon} \\
--output-dir antismash_out \\
--cpus ${task.cpus} \\
--genefinding-tool glimmerhmm \\
${assembly}

if [ ! -d "antismash_out" ]; then
echo "ERROR: antismash_out directory was not created"
exit 1
fi

NCLUSTERS=\$(grep -c "cluster" antismash_out/index.html 2>/dev/null || echo 0)
echo "INFO: antiSMASH complete — \$NCLUSTERS cluster references in index"

cat <<-END_VERSIONS > versions.yml
"${task.process}":
antismash: \$(antismash --version 2>&1 | head -1)
END_VERSIONS
"""

stub:
"""
mkdir -p antismash_out
cat > antismash_out/index.html << 'HTML'
<html><body>
<p>Cluster 1: Type I PKS</p>
<p>Cluster 2: Terpene</p>
</body></html>
HTML

cat <<-END_VERSIONS > versions.yml
"${task.process}":
antismash: stub_7.1.0
END_VERSIONS
"""
}