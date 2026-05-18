process ORTHOFINDER {
    tag "all_species"
    label 'process_high'

    input:
    path proteomes_dir // A directory containing all the .fasta protein files

    output:
    path "OrthoFinder/Results_*/Orthogroups/Orthogroups.tsv"    , emit: orthogroups
    path "OrthoFinder/Results_*/Orthogroups/Orthogroups.GeneCount.tsv", emit: gene_counts
    path "OrthoFinder/Results_*/Species_Tree/SpeciesTree_rooted.txt", emit: species_tree
    path "versions.yml"                                         , emit: versions

    script:
    """
    orthofinder -f ${proteomes_dir} -t ${task.cpus} -a ${task.cpus}
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        orthofinder: \$(orthofinder -h | grep "OrthoFinder version" | awk '{print \$3}')
    END_VERSIONS
    """
}