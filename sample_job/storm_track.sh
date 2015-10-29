#!/bin/sh
# small template for data_conv job
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh

#----- XDEF/YDEF
HGRID_LIST=( 144x72 )

#----- ZDEF(altitude)
#ZDEF=38

#----- ZDEF(pressure)
PDEF_LEVELS_LIST[0]="1000,975,950,925,900,875,850,825,800,775,750,700,650,600,550,500,450,400,350,300,250,225,200,175,150,125,100,70,50,30,20,10,7,5,3,2,1"

#----- TDEF
TGRID_LIST=( tstep 6hr_tstep )
START_YMD=20040601 ; ENDPP_YMD=20050601

#----- VAR
VARS=( \
    ms_pres      \
    ms_u         \
    ms_v         \
    ms_tem       \
    ss_slp       \
# below for composite
#    dfq_isccp2   \
#    sa_cldi      \
#    sa_cldw      \
#    sa_cld_frac  \
#    sa_evap      \
#    sa_lwu_toa   \
#    sa_lwu_toa_c \
#    sa_slp       \
#    ss_slp       \
#    sa_swu_toa   \
#    sa_swu_toa_c \
#    sa_tppn      \
#    sa_u10m      \
#    sa_v10m      \
    )

#----- Analysis flag
FLAG_TSTEP_REDUCE=1
FLAG_TSTEP_Z2PRE=1
FLAG_TSTEP_ISCCP3CAT=1
