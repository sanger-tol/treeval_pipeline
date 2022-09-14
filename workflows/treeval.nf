/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowTreeval.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [ params.fasta ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

/*

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_READ        } from '../subworkflows/local/yaml_input'
include { GENERATE_GENOME   } from '../subworkflows/local/generate_genome'
include { INSILICO_DIGEST   } from '../subworkflows/local/insilico_digest'
include { GENE_ALIGNMENT } from '../subworkflows/local/gene_alignment'
// include { SELFCOMP          } from '../subworkflows/local/selfcomp'
// include { SYNTENY           } from '../subworkflows/local/synteny'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow TREEVAL {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: reads the yaml and pushing out into a channel per yaml field
    //
    input_ch = Channel.fromPath(params.input, checkIfExists: true)

    INPUT_READ ( input_ch )

    //
    // SUBWORKFLOW: Takes input fasta file and sample ID to generate a my.genome file
    //    
    GENERATE_GENOME ( INPUT_READ.out.assembly_id, INPUT_READ.out.reference )
    ch_versions = ch_versions.mix(GENERATE_GENOME.out.versions)

    //
    //SUBWORKFLOW: 
    //
    ch_enzyme = Channel.of( "bspq1","bsss1","DLE1" )

    INSILICO_DIGEST ( INPUT_READ.out.assembly_id,
                      GENERATE_GENOME.out.dot_genome,
                      GENERATE_GENOME.out.reference_tuple,
                      ch_enzyme )
    ch_versions = ch_versions.mix(INSILICO_DIGEST.out.versions)

    //
    //SUBWORKFLOW: Takes input fasta to generate BB files containing alignment data
    //
    GENE_ALIGNMENT ( GENERATE_GENOME.out.dot_genome,
                     GENERATE_GENOME.out.reference_tuple,
                     INPUT_READ.out.assembly_classT,
                     INPUT_READ.out.align_data_dir,
                     INPUT_READ.out.align_geneset )
    ch_versions = ch_versions.mix(GENERATE_GENOME.out.versions)

    //
    //SUBWORKFLOW: 
    //
    //SELFCOMP ( GENERATE_GENOME.out.reference_tuple,
    //           GENERATE_GENOME.out.dot_genome,
    //           INPUT_READ.out.mummer_chunk,
    //           INPUT_READ.out.motif_len )
    //ch_versions = ch_versions.mix(SELFCOMP.out.versions)

    //
    //SUBWORKFLOW: 
    //
    //SYNTENY ( GENERATE_GENOME.out.reference_tuple )
    //ch_versions = ch_versions.mix(SYNTENY.out.versions)


    //
    // SUBWORKFLOW: Collates version data from prior subworflows
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
