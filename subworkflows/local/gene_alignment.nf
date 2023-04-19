#!/usr/bin/env nextflow

// This subworkflow takes an input fasta sequence and csv style list of organisms to return
// bigbed files containing alignment data between the input fasta and csv style organism names.
// Input - Assembled genomic fasta file
// Output - A BigBed file per datatype per organism entered via csv style in the yaml.

nextflow.enable.dsl=2

// MODULE IMPORT
include { PEP_ALIGNMENTS                    } from './pep_alignments'
include { NUC_ALIGNMENTS as GEN_ALIGNMENTS  } from './nuc_alignments'
include { NUC_ALIGNMENTS as RNA_ALIGNMENTS  } from './nuc_alignments'
include { NUC_ALIGNMENTS as CDS_ALIGNMENTS  } from './nuc_alignments'

workflow GENE_ALIGNMENT {
    take:
    dot_genome          // Channel: [val(meta), [ datafile ]]
    reference_tuple
    reference_index
    assembly_classT
    alignment_datadir
    alignment_genesets
    alignment_common
    intron_size
    as_files
    dbVersion

    main:
    ch_versions         = Channel.empty()

    //
    // LOGIC: TAKES A SINGLE LIKE CSV STRING AND CONVERTS TO LIST OF VALUES
    //          LIST IS MERGED WITH DATA_DIRECTORY AND ORGANISM_CLASS
    //
    ch_data             = alignment_genesets
                            .splitCsv()
                            .flatten()

    ch_data
        .combine( alignment_datadir )
        .combine( assembly_classT )
    //
    // LOGIC: CONVERTS THE ABOVE VALUES INTO A PATH AND DOWNLOADS IT, THEN TURNS IT TO A TUPLE OF
    //          [ [ META.ID, META.TYPE, META.ORG ], GENE_ALIGNMENT_FILE ]
    //          DATA IS THEN BRANCHED BASED ON META.TYPE TO THE APPROPRIATE
    //          SUBWORKFLOW
    //
        .map {
            ch_org, data_dir, classT -> file("${data_dir}${classT}/csv_data/${ch_org}-data.csv")
        }
        .splitCsv( header: true, sep:',')
        .map( row ->
        tuple([ org:    row.org,
                type:   row.type,
                id:     row.data_file.split('/')[-1].split('.MOD.')[0]
            ],
            file(row.data_file)
        ))
        .branch {
            pep: it[0].type  == 'pep'
            gen: it[0].type  == 'cdna'
            rna: it[0].type  == 'rna'
            cds: it[0].type  == 'cds'
        }
        .set {ch_alignment_data}

    pep_files = ch_alignment_data.pep.collect()
    gen_files = ch_alignment_data.gen.collect()
    rna_files = ch_alignment_data.rna.collect()
    cds_files = ch_alignment_data.cds.collect()

    //
    // SUBWORKFLOW: GENERATES GENE ALIGNMENTS FOR PEPTIDE DATA, EMITS GFF AND TBI
    //
    PEP_ALIGNMENTS (    reference_tuple,
                        pep_files
    )
    ch_versions = ch_versions.mix(PEP_ALIGNMENTS.out.versions)

    
    //
    // SUBWORKFLOW: GENERATES GENE ALIGNMENTS FOR RNA, NUCLEAR AND COMPLEMENT_DNA DATA, EMITS BIGBED
    //
    GEN_ALIGNMENTS (    reference_tuple,
                        reference_index,
                        gen_files,
                        dot_genome,
                        intron_size,
                        dbVersion
    )
    ch_versions = ch_versions.mix(GEN_ALIGNMENTS.out.versions)
    
    CDS_ALIGNMENTS (    reference_tuple,
                        reference_index,
                        cds_files,
                        dot_genome,
                        intron_size,
                        dbVersion 
    )
    ch_versions = ch_versions.mix(CDS_ALIGNMENTS.out.versions)
    
    RNA_ALIGNMENTS (    reference_tuple,
                        reference_index,
                        rna_files,
                        dot_genome,
                        intron_size,
                        dbVersion
    )
    ch_versions = ch_versions.mix(RNA_ALIGNMENTS.out.versions)

    emit:
    pep_gff             = PEP_ALIGNMENTS.out.tbi_gff
    gff_file            = PEP_ALIGNMENTS.out.gff_file
    gen_bb_files        = GEN_ALIGNMENTS.out.nuc_alignment
    rna_bb_files        = RNA_ALIGNMENTS.out.nuc_alignment
    cds_bb_files        = CDS_ALIGNMENTS.out.nuc_alignment
    versions            = ch_versions.ifEmpty(null)
}
