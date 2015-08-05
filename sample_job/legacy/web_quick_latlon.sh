#!/bin/sh
#
# for quicklook
#

#----- general -----#
OVERWRITE="no"

#----- X/Y/Z/T/V -----#
HGRID_LIST=( 144x72 zmean_72 )  # standard
TGRID_LIST=( tstep monthly_mean )  # standard

START_YMD=20040601 ; ENDPP_YMD=20040701

VARS=( \
    dfq_isccp2   \
    oa_sst       \
    sa_lwu_toa   \
    sa_lwu_toa_c \
    sa_swd_toa   \
    sa_swu_toa   \
    sa_swu_toa_c \
    sa_slp       \
    sa_t2m       \
    sa_tppn      \
    )

VARS_TSTEP=( ${VARS[@]} )           # for tstep
VARS_TSTEP_1=( ${VARS_TSTEP[@]} )   # reduce_grid.sh
#VARS_TSTEP_2_1=( ${VARS_TSTEP[@]} ) # z2pre.sh (multi level)
VARS_TSTEP_3=( ${VARS_TSTEP[@]} )   # zonal_mean.sh
