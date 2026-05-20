process DNAAPLER {
    tag "$meta.id"
   

    publishDir "${params.outdir}/dnaapler", mode: 'copy', pattern: '*.fasta'

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("${meta.id}_dnaapler.fasta"), emit: assembly
    path "versions.yml"                               , emit: versions

    script:
    """
    # If Dnaapler runs successfully (finds the gene), move its output
    if dnaapler all -i $assembly -t $task.cpus -o dnaapler_out; then
        mv dnaapler_out/*.fasta ${meta.id}_dnaapler.fasta
    
    # Else if Dnaapler fails (0 BLAST hits), just copy the original input forward
    else
        echo "WARNING: Dnaapler found 0 hits. Bypassing rotation."
        cp $assembly ${meta.id}_dnaapler.fasta
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dnaapler: \$(dnaapler --version 2>&1 | grep "dnaapler" | sed 's/dnaapler //')
    END_VERSIONS
    """
}