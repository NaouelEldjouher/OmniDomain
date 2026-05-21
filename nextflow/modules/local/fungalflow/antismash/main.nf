// modules/local/fungalflow/antismash/main.nf

process ANTISMASH {
tag "$meta.id"
label 'process_high'

container 'docker.io/antismash/standalone:7.1.0'

input:
tuple val(meta), path(assembly), path(gff)

output:
tuple val(meta), path("antismash_out/"), emit: results
path "versions.yml",                     emit: versions

when:
task.ext.when == null || task.ext.when

script:
def prefix = task.ext.prefix ?: "${meta.id}"
def args   = task.ext.args   ?: '--taxon fungi --genefinding-tool none'
def gff_arg = gff ? "--genbank-merge-gbk ${gff}" : ''
"""
#!/bin/bash
set -eo pipefail

antismash \\
${assembly} \\
--output-dir antismash_out \\
--cpus ${task.cpus} \\
${args}

NCLUSTERS=\$(grep -c "Cluster" antismash_out/index.html 2>/dev/null || echo "unknown")
echo "INFO: antiSMASH complete"

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