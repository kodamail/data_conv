#!/bin/sh
# for standard analysis and web archive
#
#- comparison with GPCP/CMAP/SRB3.0
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh

#----- XDEF/YDEF
#HGRID_LIST=( 360x181 zmean_181 )
HGRID_LIST=( 360x181 )

#----- TDEF
TGRID_LIST=( tstep monthly_mean )

#----- VAR
VARS=(
    sa_lwd_sfc
    sa_lwd_sfc_c
    sa_lwu_sfc
    sa_lwu_sfc_c
    sa_lwd_toa
    sa_lwu_toa
    sa_lwu_toa_c
    sa_swd_sfc
    sa_swd_sfc_c
    sa_swu_sfc
    sa_swu_sfc_c
    sa_swd_toa
    sa_swu_toa
    sa_swu_toa_c
    sa_tppn
    )

#----- Analysis flag
FLAG_TSTEP_REDUCE=1
#FLAG_TSTEP_ZM=1
FLAG_MM_ZM=1
