#!/bin/sh
#
# for standard analysis and web archive
#

#----- general -----#
OVERWRITE="no"

#----- X/Y/Z/T/V -----#
HGRID_LIST=( 240x121 zmean_121 )  # standard

TGRID_LIST=( tstep monthly_mean )  # standard

START_YMD=20040601 ; ENDPP_YMD=20050601

VARS=( \
    sa_cldi      \
    sa_cldw      \
    sa_evap      \
    sa_lh_sfc    \
    sa_lwd_sfc   \
    sa_lwu_sfc   \
    sa_lwu_toa   \
    sa_lwu_toa_c \
    sa_q2m       \
    sa_sh_sfc    \
    sa_slp       \
    sa_swd_sfc   \
    sa_swu_sfc   \
    sa_swd_toa   \
    sa_swu_toa   \
    sa_swu_toa_c \
    sa_t2m       \
    sa_tem_sfc   \
    sa_tppn      \
    sa_u10m      \
    sa_v10m      \
    )

VARS_TSTEP=( ${VARS[@]} )           # for tstep
VARS_TSTEP_1=( ${VARS_TSTEP[@]} )   # reduce_grid.sh
VARS_TSTEP_3=( ${VARS_TSTEP[@]} )   # zonal_mean.sh

