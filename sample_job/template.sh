#!/bin/sh
#
# template and document for data_conv job
#

#============================================================#
#
# common.sh: valid throughout a directory (optional).
#
#============================================================#
DIR_SCRIPT=$( cd $( dirname ${BASH_SOURCE:-$0} ); pwd )  # abs. path to common.sh
[ -f "${DIR_SCRIPT}/common.sh" ] && . ${DIR_SCRIPT}/common.sh
#

#============================================================#
#
# X/Y/Z/T
#
#============================================================#
#
#----- horizontal grid of output data
#
# format:
#   AAAxBBB  : (XDEF,YDEF)=(AAA,BBB)
#   zonal_BBB: zonal mean, YDEF=BBB
#
###HGRID_LIST=( 144x72 288x145 zmean_72x37 zmean_145x37 )  # standard
#HGRID_LIST=( 144x72 288x145 zmean_72 zmean_145 )
HGRID_LIST=( 144x72 )

#
#----- time grid of output data
#
# = "tstep"       : native time step
# = "monthly_mean": monthly mean
#
TGRID_LIST=( tstep monthly_mean )
#
#----- time range
#
# data are analyzed for [START_YMD:ENDPP_YMD)
#
START_YMD=20040601 ; ENDPP_YMD=20040701  # June 2004
#START_YMD=20040601 ; ENDPP_YMD=20040603

#============================================================#
#
# name of analyzed variable
#
#============================================================#
#
# For each time step,
#   L0 data are native data.
#   L1 analysis may use L0 data.
#   L2 analysis may use L0-L1 data.
#   L3 analysis may use L0-L2 data.
# For monthly mean,
#   L0-L3 time step data may be used.
#
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
#    ms_u    \
#    ms_v    \
#    ms_w    \
#    ms_rh   \
#    ms_qv   \
#    ms_qc   \
#    ms_qi   \
#    ms_qr   \
#    ms_qs   \
#    ms_qg   \
#    ms_lwhr \
#    ms_swhr \
#sl \
    )
#
FLAG_TSTEP=0   # <- not necessary: TGRID_LIST
# --- TODO: L1, L2, ... are meaningless? (just this order)
FLAG_TSTEP_L1_REDUCE=1
FLAG_TSTEP_L2_Z2PRE=0
FLAG_TSTEP_L2_PLEVOMEGA=0
FLAG_TSTEP_L2_ISCCP3CAT=0
FLAG_TSTEP_L3_ZM=1
#
#----- name of variable in time-step analysis
# just comment out below line(s) if it is not necessary.
#
#VARS_TSTEP=( ${VARS[@]} )           # all tstep analysis
#
#VARS_TSTEP_1=(   ${VARS_TSTEP[@]} ) # reduce_grid.sh
#VARS_TSTEP_2_1=( ${VARS_TSTEP[@]} ) # z2pre.sh (multi level)
VARS_TSTEP_2_3=( ms_omega )         # plev_omega.sh
VARS_TSTEP_3=(   ${VARS_TSTEP[@]} ) # zonal_mean.sh





#----- pressure levels -----#
#
# for high-top NICAM
#PDEF_LEVELS_RED[0]="1000,925,850,775,700,600,500,400,300,250,200,150,100,70,50,30,20,10,7,5,3,2,1,0.7,0.5,0.3,0.2,0.1,0.07,0.05,0.03,0.02,0.01"
#
# for comparison with ERA-Interim
PDEF_LEVELS_RED[0]="1000,975,950,925,900,875,850,825,800,775,750,700,650,600,550,500,450,400,350,300,250,225,200,175,150,125,100,70,50,30,20,10,7,5,3,2,1"

PDEF_LEVELS_RED[1]="500"

#============================================================#
#
# misc
#
#============================================================#
#
#----- overwrite flag
#
OVERWRITE="no"     # do not overwrite if data exist (default)
#OVERWRITE="yes"    # always overwrite
#OVERWRITE="rm"     # remove existing files and exit
#OVERWRITE="dry-rm" # remove existing files and exit (dry-run)

