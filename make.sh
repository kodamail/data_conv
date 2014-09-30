#!/bin/sh

# usage: ./make.sh [ configure-1 configure-2 ... ]

CONF_LIST=( )
while [ -n "$1" ] ; do
    CONF_LIST=( ${CONF_LIST[@]} $1 )
    shift
done

if [ ${#CONF_LIST[@]} -eq 0 ] ; then
    CONF_LIST=( $( ls configure/configure configure/configure.? configure/configure.?? 2> /dev/null ) )
fi


for CONF in ${CONF_LIST[@]}
do
    echo "#======================================#"
    echo "#"
    echo "# ${CONF} starts"
    echo "#"
    echo "#======================================#"
    echo ""

    ./make_core.sh ${CONF} || exit 1
    
    echo ""
    echo "#======================================#"
    echo "#"
    echo "# ${CONF} ends"
    echo "#"
    echo "#======================================#"
    echo ""
done

echo "$0 normally finished"
