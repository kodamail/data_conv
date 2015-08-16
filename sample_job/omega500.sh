#!/bin/sh
# for regime analysis such as Bony and Dufresne (2004)
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh

#----- XDEF/YDEF
HGRID_LIST=( 144x72 zmean_72 )
#HGRID_LIST=( 144x72 zmean_72_p500 )  # legacy expression

#----- ZDEF(pressure)
PDEF_LEVELS_LIST[0]="500"

#----- TDEF
TGRID_LIST=( tstep monthly_mean )
START_YMD=19780601 ; ENDPP_YMD=19780701

#----- VAR
VARS=( \
    ms_pres \
    ms_tem  \
    ms_w    \
    ms_omega \
    )

#----- Analysis flag
FLAG_TSTEP_REDUCE=1
FLAG_TSTEP_Z2PRE=1
FLAG_TSTEP_PLEVOMEGA=1
FLAG_TSTEP_ZM=1
