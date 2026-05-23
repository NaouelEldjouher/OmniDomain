process FUNANNOTATE {
    tag "$meta.id"
    label 'process_high'

    container 'nextgenusfs/funannotate:latest'

    input:
    tuple val(meta),      path(masked_fasta)
    tuple val(meta_prot), path(protein_hints)
    tuple val(meta_rna),  path(rnaseq_bam)

    output:
    tuple val(meta), path("funannotate_out/predict_results/*.gff3")       , emit: gff3
    tuple val(meta), path("funannotate_out/predict_results/*.proteins.fa*"), emit: proteins
    path "versions.yml"                                                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix   = task.ext.prefix ?: "${meta.id}"
    def args     = task.ext.args   ?: ''
    def prot_arg = ( protein_hints && protein_hints.name != 'no file' && protein_hints.size() > 0 )
        ? "--protein_evidence ${protein_hints}" : ''
    def rna_arg  = ( rnaseq_bam && rnaseq_bam.name != 'no file' && rnaseq_bam.size() > 0 )
        ? "--rna_bam ${rnaseq_bam}" : ''
    """
    funannotate sort -i ${masked_fasta} -o sorted.fa --minlen 500
    funannotate predict \\
        -i sorted.fa \\
        -o funannotate_out \\
        -s "${prefix}" \\
        --cpus ${task.cpus} \\
        ${prot_arg} \\
        ${rna_arg} \\
        ${args}
    echo '"${task.process}":' > versions.yml
    echo '    funannotate: stub_1.8.15' >> versions.yml
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p funannotate_out/predict_results
    printf '##gff-version 3\n' \
        > funannotate_out/predict_results/${prefix}.gff3
    printf 'contig_1\tFunannotate\tgene\t1000\t5000\t.\t+\t.\tID=gene1\n' \
        >> funannotate_out/predict_results/${prefix}.gff3
    printf '>stub_protein_1\nMSTARTPEPTIDE\n' \
        > funannotate_out/predict_results/${prefix}.proteins.faa
    echo '"${task.process}":' > versions.yml
    echo '    funannotate: stub_1.8.15' >> versions.yml
    """
}
