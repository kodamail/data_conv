#!/bin/sh
# for standard analysis and web archive
# for wind speed extreme analysis
#
#- comparison with JRA55
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh

#----- XDEF/YDEF
HGRID_LIST=( ${XDEF_NAT}x${YDEF_NAT} 288x145 )

#----- TDEF
TGRID_LIST=( tstep monthly_mean )

#----- VAR
VARS=(
    ss_ws10m
    )

#----- Analysis flag
FLAG_TSTEP_DERIVE=1
FLAG_TSTEP_REDUCE=1
FLAG_MM_ZM=1
