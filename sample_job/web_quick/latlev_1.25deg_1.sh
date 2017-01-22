#!/bin/sh
# for standard analysis and web archive
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh

#----- XDEF/YDEF
HGRID_LIST=( 288x145 )

#----- ZDEF(altitude)
ZDEF=38

#----- TDEF
TGRID_LIST=( tstep )
#START_YMD=20040601 ; ENDPP_YMD=20040701  # normally given by common.sh

#----- VAR
VARS=(
    ms_pres
    ms_tem
    ms_u
    )

#----- Analysis flag
FLAG_TSTEP_REDUCE=1

