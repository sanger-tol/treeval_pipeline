process GET_PAIRED_CONTACT_BED {
    tag "$meta.id"
    label 'process_low'

    conda "conda-forge::coreutils=9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
    'ubuntu:20.04' }"

    input:
    tuple val( meta ), path( file )

    output:
    tuple val( meta ), file( "*bed" ),      emit: bed
    path "versions.yml"           , emit: versions

    script:
    """
    bed_to_contacts.sh $file > ${meta.id}_paired.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bed_to_contacts: \$(bed_to_contacts.sh -v)
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_paired.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bed_to_contacts: \$(bed_to_contacts.sh -v)
    END_VERSIONS
    """
}