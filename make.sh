#!/bin/sh
#
# usage: ./make.sh [ OVERWRITE=rm ] [CNFID] job-1 [ job-2 [ job-3 ... ] ]
#
JOB_LIST=( )
CNFID_LIST=( )
OPT=""
while [[ -n "$1" ]] ; do
    if [[ -f cnf/$1.sh ]] ; then
	CNFID_LIST+=( $1 )
    elif [[ -f $1 && $1 =~ ^(./)?cnf/(.*).sh$ ]] ; then
	CNFID_LIST+=( ${BASH_REMATCH[2]} )
    elif [[ -f $1 ]] ; then
	JOB_LIST+=( $1 )
    else
	OPT="${OPT} $1"
    fi
    shift
done

if [[ ${#CNFID_LIST[@]} -eq 0 ]] ; then
    CNFID_LIST=( def )
fi
if [[ ${#JOB_LIST[@]} -eq 0 ]] ; then
    echo "usage:"
    echo "$0 [ OVERWRITE=rm ] [ CNFID-1 [ CNFID-2 ... ] ] job-1 [ job-2 ... ]"
    exit
fi

for CNFID in ${CNFID_LIST[@]} ; do
for JOB in ${JOB_LIST[@]} ; do
    [[ "${JOB}" != "${JOB%common.sh}" || "${JOB}" != "${JOB%sh~}" ]] && continue
    
    echo "#======================================#"
    echo "#"
    echo "# ${JOB} starts."
    echo "#"
    echo "#======================================#"
    echo ""

    ./make_core.sh ${CNFID} ${JOB} ${OPT} || exit 1
    
    echo ""
    echo "#======================================#"
    echo "#"
    echo "# ${JOB} ends."
    echo "#"
    echo "#======================================#"
    echo ""

done  # JOB
done  # CNFID

echo "$0 normally finished."
