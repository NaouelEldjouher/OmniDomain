process MAKER {
    tag "$meta.id"
    label 'process_high'

    input:
    tuple val(meta), path(fasta)
    tuple val(meta_rna), path(transcriptome) // Pass [] if empty
    tuple val(meta_prot), path(proteins)     // Pass [] if empty

    output:
    tuple val(meta), path("*.all.gff") , emit: gff
    path "versions.yml"                , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def est_arg  = transcriptome ? "est=${transcriptome}" : "est="
    def prot_arg = proteins ? "protein=${proteins}" : "protein="
    """
    # Generate default control files
    maker -CTL
    
    # Inject our specific evidence files into the config
    sed -i "s/^genome=.*/genome=${fasta}/" maker_opts.ctl
    sed -i "s/^est=.*/${est_arg}/" maker_opts.ctl
    sed -i "s/^protein=.*/${prot_arg}/" maker_opts.ctl
    sed -i "s/^cpus=.*/cpus=${task.cpus}/" maker_opts.ctl

    # Run MAKER
    maker -base ${prefix}

    # Gather outputs
    gff3_merge -d ${prefix}.maker.output/${prefix}_master_datastore_index.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        maker: \$(maker -version 2>&1 | awk '{print \$3}')
    END_VERSIONS
    """
}