#!/bin/sh
#
# for quicklook
#

#----- general -----#
OVERWRITE="no"

#----- X/Y/Z/T/V -----#
HGRID_LIST=( 144x72 zmean_72x37 )  # standard
TGRID_LIST=( tstep monthly_mean )

START_YMD=20040601 ; ENDPP_YMD=20040701

VARS=( \
    ms_pres \
    ms_tem  \
    ms_u    \
    )

VARS_TSTEP=( ${VARS[@]} )           # for tstep
VARS_TSTEP_1=( ${VARS_TSTEP[@]} )   # reduce_grid.sh
VARS_TSTEP_2_1=( ${VARS_TSTEP[@]} ) # z2pre.sh (multi level)
VARS_TSTEP_3=( ${VARS_TSTEP[@]} )   # zonal_mean.sh

#----- pressure levels -----#
#
# for high-top NICAM
#PDEF_LEVELS_RED[0]="1000,925,850,775,700,600,500,400,300,250,200,150,100,70,50,30,20,10,7,5,3,2,1,0.7,0.5,0.3,0.2,0.1,0.07,0.05,0.03,0.02,0.01"
#
# for comparison with ERA-Interim
PDEF_LEVELS_RED[0]="1000,975,950,925,900,875,850,825,800,775,750,700,650,600,550,500,450,400,350,300,250,225,200,175,150,125,100,70,50,30,20,10,7,5,3,2,1"

