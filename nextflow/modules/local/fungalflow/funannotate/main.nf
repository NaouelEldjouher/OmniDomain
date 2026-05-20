process FUNANNOTATE {
    tag "$meta.id"
    publishDir "${params.outdir}/02_structural_annotation", mode: 'copy'

    input:
    tuple val(meta), path(fasta), path(gff)

    output:
    tuple val(meta), path("*.gff3")       , emit: gff3
    tuple val(meta), path("*.proteins.fa"), emit: proteins
    path "versions.yml"                   , emit: versions

    script:
    """
    funannotate predict -i $fasta -g $gff -o output_dir --species "Fungus"
    mv output_dir/predict_results/*.gff3 ${meta.id}.gff3
    mv output_dir/predict_results/*.proteins.fa ${meta.id}.proteins.fa
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        funannotate: \$(funannotate --version)
    END_VERSIONS
    """

    stub:
    def prefix = "${meta.id}"
    """
    touch ${prefix}.gff3
    touch ${prefix}.proteins.fa
    touch versions.yml
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        funannotate: stub_version
    END_VERSIONS
    """
}