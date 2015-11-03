#!/bin/sh
# for standard analysis and web archive
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh

#----- XDEF/YDEF
#HGRID_LIST=( 144x72 zmean_72 )
HGRID_LIST=( 144x72 )

#----- ZDEF(pressure)
# for comparison with ERA-Interim
PDEF_LEVELS_LIST[0]="1000,975,950,925,900,875,850,825,800,775,750,700,650,600,550,500,450,400,350,300,250,225,200,175,150,125,100,70,50,30,20,10,7,5,3,2,1"

#----- TDEF
TGRID_LIST=( tstep monthly_mean )
#START_YMD=20040601 ; ENDPP_YMD=20040701  # normally given by common.sh

#----- VAR
VARS=( \
    ms_pres \
    ms_tem  \
    ms_u    \
    )

#----- Analysis flag
FLAG_TSTEP_Z2PRE=1
#FLAG_TSTEP_ZM=1

FLAG_MM_ZM=1
