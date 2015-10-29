#!/bin/sh
# for standard analysis and web archive
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh

#----- XDEF/YDEF
HGRID_LIST=( 360x181 )

#----- TDEF
TGRID_LIST=( tstep monthly_mean )

#----- VAR
VARS=( \
    sa_lwu_toa   \
    sa_lwu_toa_c \
    sa_swd_toa   \
    sa_swu_toa   \
    sa_swu_toa_c \
    )

#----- Analysis flag
FLAG_TSTEP_REDUCE=1
