#!/usr/bin/env nextflow
//
// The subworkflow takes an assembly fasta file and produce binano insilico digest cut sites track in bigbed
// Input - genome fasta
// Output - bigbed

include { MAKECMAP_FA2CMAPMULTICOLOR } from '../../modules/local/makecmap_fa2cmapmulticolor'
include { MAKECMAP_RENAMECMAPIDS } from '../../modules/local/makecmap_renamecmapids'
include { MAKECMAP_CMAP2BED } from '../../modules/local/makecmap_cmap2bed'
include { UCSC_BEDTOBIGBED } from '../../modules/nf-core/modules/ucsc/bedtobigbed/main'

workflow INSILICO_DIGEST {
    take:
    myid            // channel val(sample_id)
    sizefile        // channel [id: sample_id], my.genome_file
    sample          // channel [id: sample_id], reference_file
    ch_enzyme       // channel val( "bspq1","bsss1","DLE1" )
    dot_as          // channel val(dot_as location)

    main:
    ch_versions = Channel.empty()

    input_fasta = sample.map { data -> 
                                tuple([
                                    id               : data[0].id,
                                    single_end       : false
                                    ],
                                    file(data[1])
                                )}

    input_fasta
        .combine(ch_enzyme)
        .multiMap { data -> 
            fasta:      tuple( data[0],
                                data[1]
                            )
            enzyme:     data[2]
            }
        .set { fa2c_input } 

    MAKECMAP_FA2CMAPMULTICOLOR ( fa2c_input.fasta, fa2c_input.enzyme )

    ch_cmap    = MAKECMAP_FA2CMAPMULTICOLOR.out.cmap
    ch_cmapkey = MAKECMAP_FA2CMAPMULTICOLOR.out.cmapkey
    ch_version = ch_versions.mix(MAKECMAP_FA2CMAPMULTICOLOR.out.versions)


    ch_cmap_new = ch_cmap
        .map{ meta, cfile  -> tuple([
                                    id  :  cfile.toString().split('_')[-3]
        ], cfile)} 

    ch_cmapkey_new = ch_cmapkey
        .map{ kfile  -> tuple([
                                    id  :  kfile.toString().split('_')[-4]
        ], kfile)}


    ch_join = ch_cmap_new.join(ch_cmapkey_new)
        .map { meta, cfile, kfile -> tuple ([
                                                meta,
                                                cfile
                                                ] ,
                                            kfile)}
 
    MAKECMAP_RENAMECMAPIDS ( ch_join.map { it[0] }, ch_join.map { it[1] } )
    ch_version = ch_versions.mix(MAKECMAP_RENAMECMAPIDS.out.versions)

    ch_renamedcmap = MAKECMAP_RENAMECMAPIDS.out.renamedcmap

    MAKECMAP_CMAP2BED ( ch_renamedcmap, ch_renamedcmap.map { it[0].id } )
    ch_version = ch_versions.mix(MAKECMAP_CMAP2BED.out.versions)

    ch_bedfile = MAKECMAP_CMAP2BED.out.bedfile

    combined_ch = ch_bedfile
                    .combine(sizefile)
                    .combine(dot_as)
    
    UCSC_BEDTOBIGBED (  combined_ch.map { [it[0], it[1]] },
                        combined_ch.map { it[3] },
                        combined_ch.map { it[4] })
    ch_version = ch_versions.mix(UCSC_BEDTOBIGBED.out.versions)

    emit:
    insilico_digest_bb = UCSC_BEDTOBIGBED.out.bigbed

    versions = ch_version
}
