awk '{ if ($4 == 0) {print $0 >> "zero.bed" } else if ($4 > 1000) {print $0 >> "max.bed"}}' $1
