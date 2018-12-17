#!/bin/sh
# for standard analysis and web archive
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh

#----- XDEF/YDEF
HGRID_LIST=( 288x145 )

#----- TDEF
TGRID_LIST=( tstep monthly_mean )

#----- VAR
VARS=(
    sa_t2m
    ss_slp
    ss_slp_ecmwf
    )

#----- Analysis flag
FLAG_TSTEP_REDUCE=1
