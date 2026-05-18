// subworkflows/local/plantflow/assembly_plant.nf

include { HIFIASM } from '../../../modules/nf-core/hifiasm/main'
include { QUAST   } from '../../../modules/nf-core/quast/main'
include { BUSCO   } from '../../../modules/local/busco/main'

workflow ASSEMBLY_PLANT {
    take:
    ch_longreads // channel: [ val(meta), path(fastq) ] 
    ch_hic_reads // channel: [ val(meta), path(hic_R1), path(hic_R2) ] (Pass [] if none)

    main:
    ch_versions = Channel.empty()

    // 1. Run Hifiasm (with optional Hi-C phasing for complex plant genomes)
    HIFIASM ( ch_longreads, [], ch_hic_reads )
    
    // Extract primary assembly from the GFA graph
    ch_final_assembly = HIFIASM.out.primary_gfa.map { meta, gfa -> 
        def fasta = "${meta.id}.assembly.fasta"
        return [ meta, fasta ] 
    }
    ch_versions = ch_versions.mix(HIFIASM.out.versions)

    // 2. Assembly Metrics
    QUAST ( ch_final_assembly, [], [] )
    ch_versions = ch_versions.mix(QUAST.out.versions)

    // 3. Plant Completeness Check using the local BUSCO wrapper
    BUSCO ( ch_final_assembly, 'genome', 'embryophyta_odb10' )
    ch_versions = ch_versions.mix(BUSCO.out.versions)

    emit:
    assembly = ch_final_assembly // channel: [ val(meta), path(*.fasta) ]
    quast    = QUAST.out.tsv
    busco    = BUSCO.out.short_txt
    versions = ch_versions
}