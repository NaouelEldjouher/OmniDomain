process CAFE5 {
    tag "gene_evolution"
    label 'process_low'

    input:
    path gene_counts // The GeneCount.tsv from OrthoFinder
    path tree        // The species tree from OrthoFinder or IQ-TREE

    output:
    path "cafe_out/*"  , emit: results
    path "versions.yml", emit: versions

    script:
    """
    # CAFE 5 requires a specific format, sometimes requires a filtering step
    # but the core execution looks like this:
    cafe5 -i ${gene_counts} -t ${tree} -o cafe_out -c ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cafe5: \$(cafe5 --version | awk '{print \$2}')
    END_VERSIONS
    """
}