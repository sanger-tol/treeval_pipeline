#!/bin/bash

# get_busco_gene.sh
# -------------------
# A shell script to convert busco full_table.tsv
# into bed format for use
# in JBrowse
# -------------------
# Author = yy5

cat $1| grep -v '#'|awk '$2!="Missing"'| awk '{print $3"\t"$4"\t"$5"\t"$1"\t"$7"\t"$6"\t"$9}'| awk -F'\t' -v OFS='\t' '{if($7==""){$7="no_orthodb_link"};print $1,$2,$3,$4,$5,$6,$7}'
