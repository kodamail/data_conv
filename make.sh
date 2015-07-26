#!/bin/sh

# usage: ./make.sh [ job-1 job-2 ... ]

JOB_LIST=( )
while [ -n "$1" ] ; do
    JOB_LIST=( ${JOB_LIST[@]} $1 )
    shift
done

if [ ${#JOB_LIST[@]} -eq 0 ] ; then
    echo "usage:"
    echo "$0 job-1 job-2 ..."
    exit
#    JOB_LIST=( $( ls job/*.sh 2> /dev/null ) )
fi

for JOB in ${JOB_LIST[@]} ; do
    echo "#======================================#"
    echo "#"
    echo "# ${JOB} starts."
    echo "#"
    echo "#======================================#"
    echo ""

    ./make_core.sh ${JOB} || exit 1
    
    echo ""
    echo "#======================================#"
    echo "#"
    echo "# ${JOB} ends."
    echo "#"
    echo "#======================================#"
    echo ""
done

echo "$0 normally finished."
