process ANTISMASH {
    tag "$meta.id"
    // Do NOT set shell here — use shebang in script block instead

    input:
    tuple val(meta), path(fasta), path(gff, stageAs: "input_annotation/*")

    output:
    tuple val(meta), path("antismash_output"), emit: results
    path "versions.yml"                      , emit: versions

    script:
def prefix        = task.ext.prefix ?: "${meta.id}"
def args          = task.ext.args   ?: '--taxon plants'
def primary_fasta = fasta instanceof List
    ? ( fasta.find { !it.name.contains('.bp.') } ?: fasta.first() )
    : fasta
def input_fasta   = primary_fasta.name.endsWith('.gfa')
    ? "converted_input.fasta"
    : "${primary_fasta}"
def genefinding   = (gff && gff.size() > 0 && !gff.isDirectory())
    ? "--genefinding-gff3 ${gff}"
    : "--genefinding-tool prodigal"
"""
#!/bin/bash

# Convert GFA to FASTA if needed
if [[ "${primary_fasta.name}" == *.gfa ]]; then
    awk '/^S/ {print ">"\$2; print \$3}' ${primary_fasta} > converted_input.fasta
fi

# antiSMASH 7 with prodigal requires sequences >= 1000bp
# Filter out short contigs that cause the "only one sequence" error
awk '
    /^>/ { header=\$0; seq=""; next }
    { seq=seq\$0 }
    /^>/ || EOF { if (length(seq) >= 1000) print header"\\n"seq }
' ${input_fasta} > antismash_input.fasta

# Fallback — if filtering removed everything, use original
if [ ! -s antismash_input.fasta ]; then
    cp ${input_fasta} antismash_input.fasta
fi

NSEQS=\$(grep -c "^>" antismash_input.fasta || echo 0)
echo "INFO: Sequences for antiSMASH: \$NSEQS"

antismash \\
    ${genefinding} \\
    --cpus ${task.cpus} \\
    --output-dir antismash_output \\
    --allow-long-headers \\
    ${args} \\
    antismash_input.fasta

cat <<-END_VERSIONS > versions.yml
"${task.process}":
    antismash: \$(antismash --version 2>&1 | sed 's/antiSMASH //')
END_VERSIONS
"""
}