process BAKTA {
    tag "$meta.id"

  
    input:
    tuple val(meta), path(assembly)
    path db_path

    output:
    tuple val(meta), path("*.gbff") , emit: gbff
    tuple val(meta), path("*.gff3") , emit: gff
    tuple val(meta), path("*.tsv")  , emit: tsv
    tuple val(meta), path("*.faa")  , emit: faa
    path "versions.yml"             , emit: versions
    when:
    !params.skip_bakta
    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
  
    bakta \\
        --prefix $prefix \\
        --threads $task.cpus \\
        --db $db_path \\
        --output . \\
        --force \\
        --meta \\
        --skip-plot \\
        $assembly

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bakta: \$(bakta --version | sed 's/bakta //')
    END_VERSIONS
    """
}