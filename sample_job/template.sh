#!/bin/sh
#
# template and document for data_conv job
#
# Do not edit below two lines: Load common.sh if it exists in the same directory
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh


#
#----- horizontal grid of output data
#
# format:
#   AAAxBBB  : (XDEF,YDEF)=(AAA,BBB)
#   zonal_BBB: zonal mean, YDEF=BBB
#
###HGRID_LIST=( 2560x1280 144x72 288x145 zmean_72x37 zmean_145x37 )
HGRID_LIST=( 144x72 )

#
#----- time grid of output data
#
# = "tstep"       : native time step
# = "monthly_mean": monthly mean
#
TGRID_LIST=( tstep monthly_mean )
#TGRID_LIST=( monthly_mean )

#
#----- time range
#
# data are analyzed for [START_YMD:ENDPP_YMD)
#
START_YMD=20040601 ; ENDPP_YMD=20040701  # June 2004
#START_YMD=20040601 ; ENDPP_YMD=20040603

#
#----- name of variable for all the analysis
#
# VARS = "all": all the possible variables
#      = "sl" : single level atmospheric variable
#
VARS=( \
    ms_pres \
    ms_tem  \
    ms_w     \
    ms_omega \
    sl \
    )

#
#----- analysis flag
#
# Analysis for time step data will be done with the order below. Monthly means are performed after time step analysis.
#
# Set 0 if it is not necessary.
#
FLAG_TSTEP_REDUCE=1
FLAG_TSTEP_Z2PRE=1
FLAG_TSTEP_PLEVOMEGA=1
FLAG_TSTEP_ISCCP3CAT=1
FLAG_TSTEP_ZM=1

#
#----- pressure levels -----#
#
# for comparison with ERA-Interim
PDEF_LEVELS_RED[0]="1000,975,950,925,900,875,850,825,800,775,750,700,650,600,550,500,450,400,350,300,250,225,200,175,150,125,100,70,50,30,20,10,7,5,3,2,1"
#
# for regime analysis
PDEF_LEVELS_RED[1]="500"

#
#----- overwrite flag
#
OVERWRITE="no"     # do not overwrite if data exist (default)
#OVERWRITE="yes"    # always overwrite
#OVERWRITE="rm"     # remove existing files and exit
#OVERWRITE="dry-rm" # remove existing files and exit (dry-run)
