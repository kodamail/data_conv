#!/bin/sh

# usage: ./make.sh [ job-1 job-2 ... ]
# usage: ./make.sh OVERWRITE=rm [ job-1 job-2 ... ]

JOB_LIST=( )
OPT=""
while [ -n "$1" ] ; do
    if [ -f $1 ] ; then
	JOB_LIST=( ${JOB_LIST[@]} $1 )
    else
	OPT="${OPT} $1"
    fi
    shift
done

if [ ${#JOB_LIST[@]} -eq 0 ] ; then
    echo "usage:"
    echo "$0 job-1 job-2 ..."
    echo "$0 OVERWRITE=rm job-1 job-2 ..."
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

    ./make_core.sh ${JOB} ${OPT}|| exit 1
    
    echo ""
    echo "#======================================#"
    echo "#"
    echo "# ${JOB} ends."
    echo "#"
    echo "#======================================#"
    echo ""
done

echo "$0 normally finished."
