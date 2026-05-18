process IQTREE2 {
    tag "phylogeny"
    label 'process_medium'

    input:
    path alignment // A concatenated multiple sequence alignment (e.g., from OrthoFinder)
    path tree      // An optional starting tree

    output:
    path "*.treefile"  , emit: tree
    path "versions.yml", emit: versions

    script:
    def tree_arg = tree ? "-te ${tree}" : ""
    """
    iqtree2 -s ${alignment} ${tree_arg} -T ${task.cpus} --prefix species_phylogeny

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        iqtree2: \$(iqtree2 --version | head -n 1 | awk '{print \$3}')
    END_VERSIONS
    """
}