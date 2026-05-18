process MEDAKA {
    tag "$meta.id"
    
    

    input:
    tuple val(meta), path(assembly), path(longreads)

    output:
    tuple val(meta), path("*.polished.fasta"), emit: assembly
    path "versions.yml"                      , emit: versions

    script:
    def prefix = "${meta.id}"
    """
    
    export HOME=\$(pwd)

    medaka_consensus -i $longreads -d $assembly -o ./ -t $task.cpus -m r1041_e82_400bps_sup_v4.2.0
    
 
    mv consensus.fasta ${prefix}.polished.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        medaka: \$(medaka --version | sed 's/medaka //')
    END_VERSIONS
    """
}
