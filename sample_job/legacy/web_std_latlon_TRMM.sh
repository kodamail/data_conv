#!/bin/sh
#
# for standard analysis and web archive
#

#----- general -----#
OVERWRITE="no"

#----- X/Y/Z/T/V -----#
HGRID_LIST=( 1440x720 zmean_720 )  # standard
TGRID_LIST=( tstep monthly_mean )  # standard

START_YMD=20040601 ; ENDPP_YMD=20040603

VARS=( \
    sa_tppn      \
    )

VARS_TSTEP=( ${VARS[@]} )           # for tstep
VARS_TSTEP_1=( ${VARS_TSTEP[@]} )   # reduce_grid.sh
VARS_TSTEP_3=( ${VARS_TSTEP[@]} )   # zonal_mean.sh
