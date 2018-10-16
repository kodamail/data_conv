#!/bin/sh
# for wind speed extreme analysis
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh

#----- XDEF/YDEF
#HGRID_LIST=( 144x72 )
#HGRID_LIST=(  ${XDEF_NAT}x${YDEF_NAT}_p850 288x145_p850 )
HGRID_LIST=( ${XDEF_NAT}x${YDEF_NAT} 288x145 )

#----- ZDEF(pressure)
# for comparison with ERA-Interim
PDEF_LEVELS_LIST[0]="850"

#----- TDEF
TGRID_LIST=( tstep monthly_mean )

#----- VAR
VARS=(
    ms_ws
    )

#----- Analysis flag
FLAG_TSTEP_DERIVE=1
FLAG_TSTEP_REDUCE=1
FLAG_MM_ZM=1
