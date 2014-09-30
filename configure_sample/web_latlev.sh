#!/bin/sh
#
# for web archive
#

#----- general -----#
OVERWRITE="no"

#----- X/Y/Z/T/V -----#
HGRID_LIST=( 144x72 zmean_72 zmean_72x18 )  # standard
TGRID_LIST=( tstep monthly_mean )

START_DATE=20040601 ; ENDPP_DATE=20040602


VARS=( \
    ms_pres \
    ms_tem  \
    ms_u    \
    ms_v    \
    ms_w    \
    ms_rh   \
    ms_qv   \
    ms_qc   \
    ms_qi   \
    ms_qr   \
    ms_qs   \
    ms_qg   \
    ms_lwhr \
    ms_swhr \
    )

VARS_TSTEP=( ${VARS[@]} )           # for tstep
VARS_TSTEP_1=( ${VARS_TSTEP[@]} )   # reduce_grid.sh
VARS_TSTEP_2_1=( ${VARS_TSTEP[@]} ) # z2pre.sh (multi level)
#VARS_TSTEP_2_3=( ms_omega )         # plev_omega.sh
VARS_TSTEP_3=( ${VARS_TSTEP[@]} )   # zonal_mean.sh

#PDEF_LEVELS_RED[0]="1000,925,850,775,700,600,500,400,300,250,200,150,100,70,50,30,20,10"
PDEF_LEVELS_RED[0]="1000,925,850,775,700,600,500,400,300,250,200,150,100,70,50,30,20,10,7,5,3,2,1,0.7,0.5,0.3,0.2,0.1,0.07,0.05,0.03,0.02,0.01"
