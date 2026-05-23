process SPADES {
    tag "$meta.id"
    label 'process_high'

    container "${ workflow.containerEngine in ['singularity', 'apptainer'] ?
        'https://depot.galaxyproject.org/singularity/spades:4.0.0--h5fb382e_1' :
        'quay.io/biocontainers/spades:4.0.0--h5fb382e_1' }"

    input:
    tuple val(meta), path(reads)
    tuple val(meta2), path(longreads)

    output:
    tuple val(meta), path("spades_out/scaffolds.fasta"), emit: scaffolds
    tuple val(meta), path("spades_out/")               , emit: outdir
    path "versions.yml"                                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix    = task.ext.prefix ?: "${meta.id}"
    def args      = task.ext.args   ?: ''
    def input_pe  = reads     ? "--pe1-1 ${reads[0]} --pe1-2 ${reads[1]}" : ""
    def input_ont = longreads ? "--nanopore ${longreads}" : ""
    """
    spades.py \
        ${input_pe} \
        ${input_ont} \
        ${args} \
        -o spades_out \
        -t ${task.cpus} \
        -m ${task.memory.toGiga()}
    echo '"${task.process}":' > versions.yml
    echo '    spades: stub_4.0.0' >> versions.yml
    """

    stub:
    """
    mkdir -p spades_out
    printf '>scaffold_1 length=1000\nACGTACGTACGT\n' > spades_out/scaffolds.fasta
    echo '"${task.process}":' > versions.yml
    echo '    spades: stub_4.0.0' >> versions.yml
    """
}
