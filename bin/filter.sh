awk '{split($4,a,":");print $1"\t"$2"\t"$3"\t"a[1]"\t"$5"\t"$6}'|awk 'sqrt(($3-$2)*($3-$2)) > 5000'|sort -k 1,1 -k2,2n
