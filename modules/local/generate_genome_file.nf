process GENERATE_GENOME_FILE {
    tag "${meta.id}"
    label "process_low"

    input:
    tuple val( meta ), path( fai )

    output:
    tuple val( meta ), file( "my.genome" ),     emit: dotgenome

    script:
    """
    cut -f1,2 $fai | sort -k2,2 -nr > my.genome
    """
}