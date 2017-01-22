#!/bin/sh
# for standard analysis and web archive
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh

#----- XDEF/YDEF
HGRID_LIST=( 144x72 )

#----- TDEF
TGRID_LIST=( tstep monthly_mean )
#START_YMD=20040601 ; ENDPP_YMD=20040701  # normally given by common.sh

#----- VAR
VARS=(
    dfq_isccp2
    oa_sst
    oa_ice
    oa_icr
    sa_cldi
    sa_cldw
    sa_evap
    sa_lh_sfc
    sa_lwd_sfc
    sa_lwu_sfc
    sa_lwu_toa
    sa_lwu_toa_c
    sa_q2m
    sa_sh_sfc
    sa_slp
    sa_swd_sfc
    sa_swu_sfc
    sa_swd_toa
    sa_swu_toa
    sa_swu_toa_c
    sa_t2m
    sa_tem_sfc
    sa_tppn
    sa_u10m
    sa_v10m
    )

#----- Analysis flag
FLAG_TSTEP_ISCCP3CAT=1
FLAG_TSTEP_REDUCE=1
#FLAG_TSTEP_ZM=1

FLAG_MM_ZM=1
