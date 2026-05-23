// subworkflows/local/shared/qc_longread.nf
/*
 * Include the official nf-core modules we installed earlier
 */
include { FILTLONG } from '../../../modules/nf-core/filtlong/main'
include { NANOPLOT } from '../../../modules/nf-core/nanoplot/main'

workflow QC_LONGREAD {
    take:
    ch_raw_longreads

    main:
    ch_versions = Channel.empty()

    ch_filtlong_inputs = ch_raw_longreads.map { meta, reads -> [ meta, [], reads ] }

    FILTLONG ( ch_filtlong_inputs )
    ch_versions = ch_versions.mix( FILTLONG.out.versions_filtlong )

// NanoPlot takes [ meta, [reads] ] — wrap reads in list
    ch_nanoplot_input = FILTLONG.out.reads
        .map { meta, reads -> [ meta, [ reads ] ] }

    NANOPLOT( ch_nanoplot_input )
    ch_versions = ch_versions.mix( NANOPLOT.out.versions )

    emit:
    reads    = FILTLONG.out.reads
    html     = NANOPLOT.out.html
    txt      = NANOPLOT.out.txt     // [ meta, path(*.txt) ]
    versions = ch_versions
}