#!/bin/sh
#
# usage: ./make.sh [ OVERWRITE=rm ] [CNFID] job-1 [ job-2 [ job-3 ... ] ]
#
JOB_LIST=( )
OPT=""
CNFID=def
while [ -n "$1" ] ; do
    if [ -f cnf/$1.sh ] ; then
	CNFID=$1
    elif [ -f $1 ] ; then
	JOB_LIST=( ${JOB_LIST[@]} $1 )
    else
	OPT="${OPT} $1"
    fi
    shift
done

if [ ${#JOB_LIST[@]} -eq 0 ] ; then
    echo "usage:"
    echo "$0 [ OVERWRITE=rm ] [CNFID] job-1 [ job-2 [ job-3 ... ] ]"
    exit
fi

for JOB in ${JOB_LIST[@]} ; do
    [ "${JOB}" != "${JOB%common.sh}" -o "${JOB}" != "${JOB%sh~}" ] && continue
    
    echo "#======================================#"
    echo "#"
    echo "# ${JOB} starts."
    echo "#"
    echo "#======================================#"
    echo ""

    ./make_core.sh ${CNFID} ${JOB} ${OPT}|| exit 1
    
    echo ""
    echo "#======================================#"
    echo "#"
    echo "# ${JOB} ends."
    echo "#"
    echo "#======================================#"
    echo ""
done

echo "$0 normally finished."
