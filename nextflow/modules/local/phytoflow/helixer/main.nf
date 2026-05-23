process HELIXER {
    tag "$meta.id"
    label 'process_high'

    // CUDA container — runs in CPU fallback mode automatically when no --gpus flag
    // For AWS GPU instances (p3.2xlarge, g4dn.xlarge), add to nextflow.config:
    //   containerOptions = '--gpus all'
    //   accelerator = 1

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.helixer.gff3"), emit: gff
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix  = task.ext.prefix ?: "${meta.id}"
    def args    = task.ext.args   ?: "--lineage land_plant --species plant"
    def min_len = 21000
    """
    #!/bin/bash
    set -eo pipefail

    # Step 1: Validate input
    if [ ! -s "${fasta}" ]; then
        echo "ERROR: Input FASTA is empty — check upstream RepeatMasker output"
        exit 1
    fi

    # Step 2: Filter sequences below Helixer minimum window size
    # Sequences < 21kb cause a KeyError crash in HDF5 (/data/X missing)
    # This is expected for organelle assemblies — all contigs < 21kb
    awk '
        /^>/ {
            if (seq && length(seq) >= ${min_len}) print header"\\n"seq
            header=\$0; seq=""
        }
        !/^>/ { seq=seq\$0 }
        END {
            if (seq && length(seq) >= ${min_len}) print header"\\n"seq
        }
    ' ${fasta} > helixer_input.fasta

    # Step 3: Count qualifying sequences
    NSEQS=\$(grep -c "^>" helixer_input.fasta 2>/dev/null || echo 0)
    echo "INFO: Sequences passing length filter (>= ${min_len} bp): \$NSEQS"

    # Step 4: Run Helixer or emit minimal valid GFF3
    if [ "\$NSEQS" -eq 0 ]; then
        echo "WARNING: No sequences >= ${min_len} bp found"
        echo "WARNING: Helixer requires nuclear genome sequences"
        echo "WARNING: Use --run_helixer false for organelle-only assemblies"
        cat > ${prefix}.helixer.gff3 << 'GFF'
##gff-version 3
## Helixer skipped: no sequences >= 21000 bp (organelle assembly)
GFF
    else
        Helixer.py \\
            --fasta-path helixer_input.fasta \\
            --gff-output-path ${prefix}.helixer.gff3 \\
            ${args}

        NGENES=\$(grep -c "\\bgene\\b" ${prefix}.helixer.gff3 2>/dev/null || echo 0)
        echo "INFO: Helixer predicted \$NGENES genes"
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        helixer: \$(Helixer.py --version 2>&1 | sed 's/Helixer //' || echo "v0.3.3")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Stub produces valid GFF3 with proper feature hierarchy
    # antiSMASH and MAKER need parent-child relationships to parse correctly
    cat > ${prefix}.helixer.gff3 << 'GFF'
##gff-version 3
##sequence-region stub_seq 1 154000
stub_seq\tHelixer\tgene\t1000\t5000\t.\t+\t.\tID=gene1;Name=stub_gene1
stub_seq\tHelixer\tmRNA\t1000\t5000\t.\t+\t.\tID=mrna1;Parent=gene1
stub_seq\tHelixer\tfive_prime_UTR\t1000\t1099\t.\t+\t.\tID=utr5_1;Parent=mrna1
stub_seq\tHelixer\tCDS\t1100\t4900\t.\t+\t0\tID=cds1;Parent=mrna1
stub_seq\tHelixer\tthree_prime_UTR\t4901\t5000\t.\t+\t.\tID=utr3_1;Parent=mrna1
stub_seq\tHelixer\tgene\t10000\t15000\t.\t-\t.\tID=gene2;Name=stub_gene2
stub_seq\tHelixer\tmRNA\t10000\t15000\t.\t-\t.\tID=mrna2;Parent=gene2
stub_seq\tHelixer\tCDS\t10100\t14900\t.\t-\t0\tID=cds2;Parent=mrna2
GFF

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        helixer: stub_v0.3.3
    END_VERSIONS
    """
}
