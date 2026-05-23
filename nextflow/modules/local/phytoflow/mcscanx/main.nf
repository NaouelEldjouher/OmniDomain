process MCSCANX {
    tag "synteny"
    label 'process_medium'

    input:
    path proteomes_dir
    path gffs_dir

    output:
    path "*.collinearity", emit: synteny
    path "versions.yml"  , emit: versions

    script:
    """
    # Note: MCScanX expects an all-vs-all BLAST and a unified GFF. 
    # In a real run, you use diamond blastp here first, then run MCScanX.
    
    cat ${proteomes_dir}/*.fasta > all_species.fasta
    cat ${gffs_dir}/*.gff > all_species.gff
    
    diamond makedb --in all_species.fasta -d all_species
    diamond blastp -q all_species.fasta -d all_species -e 1e-10 -p ${task.cpus} -o all_species.blast
    
    MCScanX all_species

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mcscanx: "custom_build"
    END_VERSIONS
    """
}