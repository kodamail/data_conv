#!/bin/sh
# for standard analysis and web archive
#
#- comparison with JRA55
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh

#----- XDEF/YDEF
HGRID_LIST=( 288x145 )

#----- TDEF
TGRID_LIST=( tstep monthly_mean )
#START_YMD=20040601 ; ENDPP_YMD=20040701  # normally given by common.sh

#----- VAR
VARS=( \
    sa_q2m       \
    sa_t2m       \
    sa_u10m      \
    sa_v10m      \
    )

#----- Analysis flag
FLAG_TSTEP_REDUCE=1
FLAG_TSTEP_ZM=0
