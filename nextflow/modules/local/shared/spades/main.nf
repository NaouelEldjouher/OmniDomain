process SPADES {
tag "$meta.id"
label 'process_high'

container 'staphb/spades:4.0.0'

input:
tuple val(meta),      path(shortreads)
tuple val(meta_long), path(longreads)    // pass [ [id:'empty'], [] ] when no long reads

output:
tuple val(meta), path("spades_out/scaffolds.fasta"), emit: scaffolds
path "versions.yml"                               , emit: versions

when:
task.ext.when == null || task.ext.when

script:
def prefix   = task.ext.prefix ?: "${meta.id}"
def args     = task.ext.args   ?: '--isolate'
// Only add --nanopore if long reads file is real and non-empty
def ont_arg  = ( longreads && longreads.size() > 0 ) ? "--nanopore ${longreads}" : ""
// Switch to hybrid mode automatically if ONT reads provided
def mode_arg = ont_arg ? "" : args   // --isolate incompatible with --nanopore
"""
#!/bin/bash
set -eo pipefail

NREADS=\$(zcat ${shortreads[0]} | wc -l | awk '{print \$1/4}')
echo "INFO: Running SPAdes on \$NREADS short read pairs"
[ -n "${ont_arg}" ] && echo "INFO: Hybrid mode — ONT reads included"

spades.py \\
-1 ${shortreads[0]} \\
-2 ${shortreads[1]} \\
${ont_arg} \\
${mode_arg} \\
--threads ${task.cpus} \\
--memory ${task.memory.toGiga()} \\
-o spades_out

if [ ! -s spades_out/scaffolds.fasta ]; then
echo "ERROR: SPAdes produced empty scaffolds.fasta"
exit 1
fi

NCONTIGS=\$(grep -c "^>" spades_out/scaffolds.fasta)
echo "INFO: Assembly complete — \$NCONTIGS scaffolds"

cat <<-END_VERSIONS > versions.yml
"${task.process}":
spades: \$(spades.py --version 2>&1 | grep -oE "[0-9]+\\.[0-9]+\\.[0-9]+" | head -1)
END_VERSIONS
"""

stub:
"""
mkdir -p spades_out

# Stub produces a real FASTA — empty file triggers size validation error
printf '>scaffold_1 length=50000 cov=45.2\\n'  > spades_out/scaffolds.fasta
printf '>scaffold_2 length=35000 cov=48.7\\n' >> spades_out/scaffolds.fasta
printf '>scaffold_3 length=22000 cov=51.1\\n' >> spades_out/scaffolds.fasta

cat <<-END_VERSIONS > versions.yml
"${task.process}":
spades: stub_4.0.0
END_VERSIONS
"""
}