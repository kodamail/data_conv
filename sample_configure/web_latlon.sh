#!/bin/sh
#
# for web archive
#

#----- general -----#
OVERWRITE="no"

#----- X/Y/Z/T/V -----#
#HGRID_LIST=( 144x72 2560x1280 )
HGRID_LIST=( 144x72 360x181 2560x1280 zmean_72 zmean_1280 )  # standard
#HGRID_LIST=( 360x181 )
#HGRID_LIST=( 288x145 )  # extra
TGRID_LIST=( tstep monthly_mean )  # standard
#TGRID_LIST=( monthly_mean )

START_DATE=20040601 ; ENDPP_DATE=20040701


VARS=( \
    dfq_isccp2   \
    oa_sst       \
    oa_ice       \
    oa_icr       \
    sa_cldi      \
    sa_cldw      \
    sa_lh_sfc    \
    sa_lwd_sfc   \
    sa_lwu_sfc   \
    sa_lwu_toa   \
    sa_lwu_toa_c \
    sa_q2m       \
    sa_sh_sfc    \
    sa_swd_sfc   \
    sa_swu_sfc   \
    sa_swd_toa   \
    sa_swu_toa   \
    sa_swu_toa_c \
    sa_slp       \
    sa_t2m       \
    sa_tppn      \
    )
VARS=( sa_t2m )

#VARS_TSTEP=( ${VARS[@]} )           # for tstep
VARS_TSTEP_1=( ${VARS_TSTEP[@]} )   # reduce_grid.sh
VARS_TSTEP_2_1=( ${VARS_TSTEP[@]} ) # z2pre.sh (multi level)
VARS_TSTEP_3=( ${VARS_TSTEP[@]} )   # zonal_mean.sh

#PDEF_LEVELS_RED[0]="1000,925,850,775,700,600,500,400,300,250,200,150,100,70,50,30,20,10"
