#!/bin/sh
# for standard analysis and web archive
#
#- comparison with ERA-Interim
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh

#----- XDEF/YDEF
#HGRID_LIST=( 240x121 zmean_121 )
HGRID_LIST=( 240x121 )

#----- TDEF
TGRID_LIST=( tstep monthly_mean )

#----- VAR
VARS=(
    sa_t2m
    )

#----- Analysis flag
FLAG_TSTEP_REDUCE=1
#FLAG_TSTEP_ZM=1

FLAG_MM_ZM=1
