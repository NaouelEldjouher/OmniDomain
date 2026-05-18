// subworkflows/local/fungalflow/assembly_fungal.nf

/*
 * Include community nf-core modules and local fallback tools
 */
include { HIFIASM    } from '../../../modules/nf-core/hifiasm/main'
include { UNICYCLER  } from '../../../modules/local/unicycler/main'
include { QUAST      } from '../../../modules/nf-core/quast/main'
include { BUSCO      } from '../../../modules/local/busco/main'

workflow ASSEMBLY_FUNGAL {
    take:
    ch_longreads  // channel: [ val(meta), path(fastq) ] (Pass empty [] if short-read only)
    ch_shortreads // channel: [ val(meta), path(fastq) ] (Pass empty [] if long-read only)
    ch_busco_db   // path: path to downloaded fungal BUSCO lineage dataset

    main:
    ch_versions = Channel.empty()
    ch_final_assembly = Channel.empty()

    // 1. Logic Router: Build assembly based on input availability
    if ( ch_longreads && !ch_shortreads ) {
        // High-fidelity PacBio HiFi / ONT assembly loop
        HIFIASM ( ch_longreads, [], [] )
        
        // Extract primary contigs from hifiasm gfa format into standard fasta
        ch_final_assembly = HIFIASM.out.primary_gfa.map { meta, gfa -> 
            def fasta = "${meta.id}.assembly.fasta"
            // Simple shell execution block mock for extraction inside Nextflow channel maps
            return [ meta, fasta ] 
        }
        ch_versions = ch_versions.mix(HIFIASM.out.versions)

    } else {
        // Short-read or hybrid fallback execution path via Unicycler
        UNICYCLER ( ch_shortreads, ch_longreads )
        ch_final_assembly = UNICYCLER.out.gfa_or_fasta
        ch_versions = ch_versions.mix(UNICYCLER.out.versions)
    }

    // 2. Structural Validation Phase (Run QUAST metrics)
    QUAST ( ch_final_assembly, [], [] )
    ch_versions = ch_versions.mix(QUAST.out.versions)

    // 3. Biological Completeness Phase (Run BUSCO gene tracking)
    BUSCO ( ch_final_assembly, ch_busco_db, [], [] )
    ch_versions = ch_versions.mix(BUSCO.out.versions)

    emit:
    assembly = ch_final_assembly    // channel: [ val(meta), path(*.fasta) ]
    quast_tsv = QUAST.out.tsv       // channel: [ val(meta), path(*.tsv) ] for metrics UI
    busco_txt = BUSCO.out.short_txt // channel: [ val(meta), path(*.txt) ] for profile charts
    versions  = ch_versions         // channel: [ path(versions.yml) ]
}