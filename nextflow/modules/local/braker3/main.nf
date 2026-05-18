process BRAKER3 {
    tag "$meta.id"
    label 'process_high'

    input:
    tuple val(meta), path(fasta)
    path protein_hints
    tuple val(meta_rna), path(bam) // Pass [] in workflow if no RNA-seq is available

    output:
    tuple val(meta), path("braker_out/*.gff3"), emit: gff
    path "versions.yml"                       , emit: versions

    script:
    // Dynamically include BAM if RNA-seq data was provided
    def bam_arg = bam ? "--bam=${bam}" : ""
    """
    braker.pl \\
        --genome=${fasta} \\
        --prot_seq=${protein_hints} \\
        ${bam_arg} \\
        --threads ${task.cpus} \\
        --gff3 \\
        --workingdir=braker_out

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        braker3: \$(braker.pl --version | head -n 1 | awk '{print \$2}')
    END_VERSIONS
    """
}