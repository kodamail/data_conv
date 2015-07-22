#!/bin/sh
#
# for standard analysis and web archive
#

#----- general -----#
OVERWRITE="no"

#----- X/Y/Z/T/V -----#
HGRID_LIST=( 144x72 zmean_72 )  # standard
TGRID_LIST=( tstep monthly_mean )  # standard

START_DATE=20040601 ; ENDPP_DATE=20040701

VARS=( \
    dfq_isccp2   \
    )

VARS_TSTEP=( ${VARS[@]} )           # for tstep
VARS_TSTEP_1=( ${VARS_TSTEP[@]} )   # reduce_grid.sh
VARS_TSTEP_2_9=( ${VARS_TSTEP[@]} ) # ISCCP
VARS_TSTEP_3=( ${VARS_TSTEP[@]} )   # zonal_mean.sh
