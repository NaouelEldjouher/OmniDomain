process FUNANNOTATE {
tag "$meta.id"
label 'process_high'

container 'nextflowio/funannotate:latest'

input:
tuple val(meta), path(masked_fasta)              // masked assembly
tuple val(meta_prot), path(protein_hints)        // optional proteins
tuple val(meta_rna),  path(rnaseq_bam)           // optional RNA-seq BAM

output:
tuple val(meta), path("funannotate_out/*.gff3"),         emit: gff3
tuple val(meta), path("funannotate_out/*.proteins.faa"), emit: proteins
path "versions.yml",                                     emit: versions

when:
task.ext.when == null || task.ext.when

script:
def prefix    = task.ext.prefix ?: "${meta.id}"
def args      = task.ext.args   ?: ''
def prot_arg  = protein_hints   ? "--protein_evidence ${protein_hints}" : ''
def rna_arg   = rnaseq_bam      ? "--rna_bam ${rnaseq_bam}"            : ''
"""
#!/bin/bash
set -eo pipefail

funannotate predict \\
-i ${masked_fasta} \\
-o funannotate_out \\
-s "${prefix}" \\
--cpus ${task.cpus} \\
${prot_arg} \\
${rna_arg} \\
${args}

cat <<-END_VERSIONS > versions.yml
"${task.process}":
funannotate: \$(funannotate --version 2>&1 | head -1)
END_VERSIONS
"""

stub:
def prefix = task.ext.prefix ?: "${meta.id}"
"""
mkdir -p funannotate_out

printf '##gff-version 3\\n' > funannotate_out/${prefix}.gff3
printf 'contig_1\\tFunannotate\\tgene\\t1000\\t5000\\t.\\t+\\t.\\tID=gene1\\n' \
        >> funannotate_out/${prefix}.gff3

    printf '>stub_protein_1\\nMSTARTPEPTIDE\\n' \
> funannotate_out/${prefix}.proteins.faa

cat <<-END_VERSIONS > versions.yml
"${task.process}":
funannotate: stub_1.8.15
END_VERSIONS
"""
}