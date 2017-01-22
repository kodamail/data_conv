#!/bin/sh
# for standard analysis and web archive (ISCCP)
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh

#----- XDEF/YDEF
HGRID_LIST=( 144x72 )

#----- ZDEF(altitude)
ZDEF=38

#----- TDEF
TGRID_LIST=( monthly_mean )
#START_YMD=20040601 ; ENDPP_YMD=20040701  # normally given by common.sh

#----- VAR
VARS=(
    ms_pres
    )
