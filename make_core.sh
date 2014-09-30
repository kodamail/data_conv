#!/bin/sh
#
# flexible analysis system for NICAM output
#
# last updated 2011.11.25
#
# TODO: combine TID(DAYS) and YEAR/MONTH -> DATE
# TODO: support z->p for native grid (such as for gl06)
# TODO: complex configure (e.g. using namelist-like syntax)
# TODO: when monthly-mean or zonal-mean, if most (>90%) of the values are undef, then the resulting mean value should be set to undef, like legacy data_conv
# TODO: create land/sea mask from la_tg (undef -> ocean)
#
. ./common.sh     || exit 1
. ./usr/common.sh || exit 1

CONF=$1
[ ! -f "${CONF}" ] && { echo "error: ${CONF} does not exist" ; exit 1 ; }

### comment out if you use log file instead of displaying.
###LOG_STDOUT=/dev/stdout
###LOG_STDERR=/dev/stderr

echo "make_core.sh start" # 1>> ${LOG_STDOUT} 2>> ${LOG_STDERR}
date                      # 1>> ${LOG_STDOUT} 2>> ${LOG_STDERR}
#############################################################
# configure
#############################################################
. ${CONF}
KEY_LIST=( isccp ll ml_zlev ml_plev ol sl advanced/cosp_v1.3 advanced/MIM-0.36r2 )

#############################################################
# Expand VARS
#############################################################
VARS=( $( expand_vars ${#VARS[@]} ${VARS[@]} ) )

#############################################################
# Basic Analysis (tstep)
#############################################################
VARS_TSTEP=( $( expand_vars ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) )
VARS_TSTEP=( $( dep_var ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} \
                        ${#VARS[@]}       ${VARS[@]} ) )

#for DAYS in ${DAYS_LIST_TSTEP[@]} ; do
#for TID in ${TID_LIST_TSTEP[@]} ; do

echo "############################################################"
echo "#"
echo "# Basic Analysis (tstep)"
echo "#"
echo "############################################################"
echo "#"
########## 0 ISCCP special ##########
# to create 3-category tstep data
#
#
#===== DAYS->TID not checked =====#
#    DIR_IN=../isccp/${XDEF_NAT}x${YDEF_NAT}x${ZDEF_ISCCP}/tstep
#    DIR_OUT=../isccp/${XDEF_NAT}x${YDEF_NAT}x3/tstep
#    VARS_TSTEP_ISCCP=( $( expand_vars ${#VARS_TSTEP_ISCCP[@]} ${VARS_TSTEP_ISCCP[@]} ) )
#    VARS_TEMP=( ${VARS_TSTEP_ISCCP[@]} )
##    [ "${VARS_TSTEP_ISCCP[0]}" = "ALL" ] && VARS_TEMP=( dfq_isccp2 )
#    VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
#                           ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) )
#    if [ "${VARS_TEMP[0]}" = "dfq_isccp2" ] ; then
#	./isccp_3cat.sh ${DAYS} ${DIR_IN} ${DIR_OUT} \
#	    ${OVERWRITE} || exit 1
#    fi

########## 1. reduce grid ##########
#
DIR_IN_LIST=( \
    ../../isccp/${XDEF_NAT}x${YDEF_NAT}x${ZDEF_ISCCP}/tstep \
    ../../isccp/${XDEF_NAT}x${YDEF_NAT}x3/tstep \
    ../../ll/${XDEF_NAT}x${YDEF_NAT}/tstep \
    ../../ml_zlev/${XDEF_NAT}x${YDEF_NAT}x${ZDEF_NAT}/tstep \
    ../../ol/${XDEF_NAT}x${YDEF_NAT}/tstep \
    ../../sl/${XDEF_NAT}x${YDEF_NAT}/tstep \
    )
for DIR_IN in ${DIR_IN_LIST[@]} ; do
    [ ! -d ${DIR_IN} ] && continue
    #
    VARS_TSTEP_1=( $( expand_vars ${#VARS_TSTEP_1[@]} ${VARS_TSTEP_1[@]} ) )
    VARS_TEMP=( ${VARS_TSTEP_1[@]} )
    VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
	        ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]}) )

    #echo "${VARS_TEMP[@]}"
    for VAR in ${VARS_TEMP[@]} ; do
	VAR_CHILD=$( ls --color=never ${DIR_IN} 2>/dev/null | grep ^${VAR}$ )
	[ "${VAR_CHILD}" != "${VAR}" ] && continue
	#
	INPUT_CTL=${DIR_IN}/${VAR}/${VAR}.ctl
	PERIOD=$( tstep_2_period ${INPUT_CTL} ) || exit 1
	DIR_IN_NEW=$( echo ${DIR_IN} | sed -e "s|/tstep$|/${PERIOD}|" )
	#DIR_IN_NEW=${DIR_IN%tstep}${PERIOD}
	#
	for HGRID in ${HGRID_LIST[@]} ; do
	    [ "${HGRID}" = "${XDEF_NAT}x${YDEF_NAT}" ] && continue
	    [ "$( echo ${HGRID} | sed -e "s/[0-9]\+x[0-9]\+//" )" != "" ] && continue
	    DIR_OUT=$( conv_dir ${DIR_IN_NEW} XYDEF=${HGRID} ) || exit 1
	    ./reduce_grid2.sh ${START_DATE} ${ENDPP_DATE} \
		${DIR_IN_NEW} ${DIR_OUT} \
		${HGRID} ${OVERWRITE} ${VAR} || exit 1
	    #
	    mkdir -p ${DIR_OUT}/../tstep
	    cd ${DIR_OUT}/../tstep
	    [ ! -d ${VAR} -a ! -L ${VAR} ] && ln -s ../${PERIOD}/${VAR}
	    cd - > /dev/null
	done
    done
done


########## 2. z -> p ##########
#
# multi pressure levels in low horizontal resolution
#
DIR_IN_LIST=( )
for KEY in ml_zlev ; do
    for HGRID in ${HGRID_LIST[@]} ; do
	[ "$( echo ${HGRID} | sed -e "s/[0-9]\+x[0-9]\+//" )" != "" ] && continue
#	for TGRID in ${TGRID_LIST[@]} ; do
	for TGRID in tstep ; do
	    for DIR_IN in ../../${KEY}/${HGRID}x${ZDEF_NAT}/${TGRID} ; do
		[ -d ${DIR_IN} ] && DIR_IN_LIST=( ${DIR_IN_LIST[@]} ${DIR_IN} )
	    done
	done
    done
done
for DIR_IN in ${DIR_IN_LIST[@]} ; do
    echo ${DIR_IN}
    [ ! -d ${DIR_IN} ] && continue
    VARS_TSTEP_2_1=( $( expand_vars ${#VARS_TSTEP_2_1[@]} ${VARS_TSTEP_2_1[@]} ) )
    VARS_TEMP=( ${VARS_TSTEP_2_1[@]} )
    VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
	        ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) )
    for VAR in ${VARS_TEMP[@]} ; do
	[ "${VAR}" = "ms_pres" ] && continue
	PDEF=$( get_pdef ${PDEF_LEVELS_RED[0]} ) || exit 1
	VAR_CHILD=$( ls --color=never ${DIR_IN} 2>/dev/null | grep ^${VAR}$ )
	[ "${VAR_CHILD}" != "${VAR}" ] && continue
	#
	INPUT_CTL=${DIR_IN}/${VAR}/${VAR}.ctl
	PERIOD=$( tstep_2_period ${INPUT_CTL} ) || exit 1
	DIR_IN_NEW=$( echo ${DIR_IN} | sed -e "s|/tstep$|/${PERIOD}|" )
	#
	DIR_OUT=$( conv_dir ${DIR_IN_NEW} TAG=ml_plev ) || exit 1
	if [ ${PDEF} -eq 1 ] ; then
	    DIR_OUT=$( conv_dir ${DIR_OUT} ZLEV=${PDEF_LEVELS_RED[0]} ) || exit 1
	else
	    DIR_OUT=$( conv_dir ${DIR_OUT} ZDEF=${PDEF} ) || exit 1
	fi
	./z2pre.sh ${START_DATE} ${ENDPP_DATE} \
	    ${DIR_IN_NEW} ${DIR_OUT} \
	    ${PDEF_LEVELS_RED[0]} ${OVERWRITE} ${VAR} || exit 1
	#
	RESULT=$( diff ${DIR_IN_NEW}/${VAR}/${VAR}.ctl ${DIR_IN_NEW}/../tstep/${VAR}/${VAR}.ctl ) || exit 1
	if [ "${RESULT}" = "" ] ; then
	    mkdir -p ${DIR_OUT}/../tstep
	    cd ${DIR_OUT}/../tstep
	    [ ! -d ${VAR} -a ! -L ${VAR} ] && ln -s ../${PERIOD}/${VAR}
	    cd - > /dev/null
	fi
    done
done

echo "ok"
exit


#    #
#    # one pressure level in high horizontal resolution -> use multiple-configure instead!
#    #
#
#    DIR_IN=../ml_zlev/${XDEF_NAT}x${YDEF_NAT}x${ZDEF_NAT}/tstep
#    if [ -d ${DIR_IN} ] ; then
#	VARS_TSTEP_2_2=( $( expand_vars ${#VARS_TSTEP_2_2[@]} ${VARS_TSTEP_2_2[@]} ) )
#	VARS_TEMP=( ${VARS_TSTEP_2_2[@]} )
#	#[ "${VARS_TSTEP_2_2[0]}" = "ALL" ] && VARS_TEMP=( `ls ${DIR_IN}` )
#	VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
#                               ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) )
#	for VAR in ${VARS_TEMP[@]} ; do
#	    for PDEF_LEVELS in ${PDEF_LEVELS_NAT[@]} ; do
#	        PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1
#		VAR_CHILD=$( ls --color=never ${DIR_IN} 2>/dev/null | grep ^${VAR}$ )
#		[ "${VAR_CHILD}" != "${VAR}" ] && continue
#		DIR_OUT=../ml_plev/${XDEF_NAT}x${YDEF_NAT}_p${PDEF_LEVELS}/tstep
#		./z2pre.sh ${TID} ${DIR_IN} ${DIR_OUT} \
#		    ${PDEF_LEVELS} ${OVERWRITE} ${VAR} || exit 1
#	    done
#	done
#    fi

#
# omega velocity in low horizontal resolution
#
DIR_IN_LIST=( )
PDEF=$( get_pdef ${PDEF_LEVELS_RED[0]} ) || exit 1
for KEY in ml_plev ; do
    for HGRID in ${HGRID_LIST[@]} ; do
	[ "$( echo ${HGRID} | sed -e "s/[0-9]\+x[0-9]\+//" )" != "" ] && continue
	for TGRID in tstep ; do
	    for DIR_INOUT in ../${KEY}/${HGRID}x${PDEF}/${TGRID} ; do
		[ -d ${DIR_INOUT} ] && DIR_INOUT_LIST=( ${DIR_INOUT_LIST[@]} ${DIR_INOUT} )
	    done
	done
    done
done
for DIR_INOUT in ${DIR_INOUT_LIST[@]} ; do
    [ ! -d ${DIR_INOUT} ] && continue
    VARS_TSTEP_2_3=( $( expand_vars ${#VARS_TSTEP_2_3[@]} ${VARS_TSTEP_2_3[@]} ) )
    VARS_TEMP=( ${VARS_TSTEP_2_3[@]} )
    VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
	        ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) )
    for VAR in ${VARS_TEMP[@]} ; do
	[ "${VAR}" != "ms_omega" ] && continue
	PDEF=$( get_pdef ${PDEF_LEVELS_RED[0]} ) || exit 1
	#
	INPUT_CTL=${DIR_INOUT}/ms_w/ms_w.ctl
	PERIOD=$( tstep_2_period ${INPUT_CTL} ) || exit 1
	DIR_INOUT_NEW=$( echo ${DIR_INOUT} | sed -e "s|/tstep$|/${PERIOD}|" )
	#
	./plev_omega.sh ${START_DATE} ${ENDPP_DATE} \
	    ${DIR_INOUT_NEW} \
	    ${PDEF_LEVELS_RED[0]} ms_w ms_rho ${OVERWRITE} || exit 1
	#
	RESULT=$( diff ${DIR_INOUT_NEW}/ms_w/ms_w.ctl ${DIR_INOUT_NEW}/../tstep/ms_w/ms_w.ctl ) || exit 1
	if [ "${RESULT}" = "" ] ; then
	    mkdir -p ${DIR_INOUT}/../tstep
	    cd ${DIR_INOUT}/../tstep
	    [ ! -d ${VAR} -a ! -L ${VAR} ] && ln -s ../${PERIOD}/${VAR}
	    cd - > /dev/null
	fi
    done
done
#
# geopotantial height in low horizontal resolution
#
DIR_IN_LIST=( )
for KEY in ml_zlev ; do
    for HGRID in ${HGRID_LIST[@]} ; do
	[ "$( echo ${HGRID} | sed -e "s/[0-9]\+x[0-9]\+//" )" != "" ] && continue
	for TGRID in tstep ; do
	    for DIR_IN in ../${KEY}/${HGRID}x${ZDEF_NAT}/${TGRID} ; do
		[ -d ${DIR_IN} ] && DIR_IN_LIST=( ${DIR_IN_LIST[@]} ${DIR_IN} )
	    done
	done
    done
done
for DIR_IN in ${DIR_IN_LIST[@]} ; do
    [ ! -d ${DIR_IN} ] && continue
    VARS_TSTEP_2_4=( $( expand_vars ${#VARS_TSTEP_2_4[@]} ${VARS_TSTEP_2_4[@]} ) )
    VARS_TEMP=( ${VARS_TSTEP_2_4[@]} )
    VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
	        ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) )
    for VAR in ${VARS_TEMP[@]} ; do
	[ "${VAR}" != "ms_z" ] && continue
	PDEF=$( get_pdef ${PDEF_LEVELS_RED[0]} ) || exit 1
	#
	INPUT_CTL=${DIR_IN}/ms_pres/ms_pres.ctl
	PERIOD=$( tstep_2_period ${INPUT_CTL} ) || exit 1
	DIR_IN_NEW=$( echo ${DIR_IN} | sed -e "s|/tstep$|/${PERIOD}|" )
	#
	DIR_OUT=$( conv_dir ${DIR_IN_NEW} TAG=ml_plev ) || exit 1
	if [ ${PDEF} -eq 1 ] ; then
	    DIR_OUT=$( conv_dir ${DIR_OUT} ZLEV=${PDEF_LEVELS_RED[0]} ) || exit 1
	else
	    DIR_OUT=$( conv_dir ${DIR_OUT} ZDEF=${PDEF} ) || exit 1
	fi
	./plev_z.sh ${START_DATE} ${ENDPP_DATE} \
	    ${DIR_IN_NEW} ${DIR_OUT} \
	    ${PDEF_LEVELS_RED[0]} ms_pres ${OVERWRITE} || exit 1
	#
	RESULT=$( diff ${DIR_IN_NEW}/ms_pres/ms_pres.ctl ${DIR_IN_NEW}/../tstep/ms_pres/ms_pres.ctl ) || exit 1
	if [ "${RESULT}" = "" ] ; then
	    mkdir -p ${DIR_OUT}/../tstep
	    cd ${DIR_OUT}/../tstep
	    [ ! -d ${VAR} -a ! -L ${VAR} ] && ln -s ../${PERIOD}/${VAR}
	    cd - > /dev/null
	fi
    done
done


#
# vertical integral
#
DIR_IN_LIST=( )
for KEY in ml_zlev ; do
    for HGRID in ${HGRID_LIST[@]} ; do
	for TGRID in tstep ; do
	    for DIR_IN in ../${KEY}/${HGRID}x${ZDEF_NAT}/${TGRID} ; do
		[ -d ${DIR_IN} ] && DIR_IN_LIST=( ${DIR_IN_LIST[@]} ${DIR_IN} )
	    done
	done
    done
done
for DIR_IN in ${DIR_IN_LIST[@]} ; do
    [ ! -d ${DIR_IN} ] && continue
    
    VARS_TSTEP_2_5=( $( expand_vars ${#VARS_TSTEP_2_5[@]} ${VARS_TSTEP_2_5[@]} ) )
    VARS_TEMP=( ${VARS_TSTEP_2_5[@]} )
	#[ "${VARS_TSTEP_2_3[0]}" = "ALL" ] && VARS_TEMP=( $( ls ${DIR_IN} ) )
    VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
	${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) )
    for VAR in ${VARS_TEMP[@]} ; do
	INPUT_CTL=${DIR_IN}/${VAR}/${VAR}.ctl
	PERIOD=$( tstep_2_period ${INPUT_CTL} )
	DIR_OUT=$( echo "${DIR_IN}" \
	    | sed -e "s/ml_zlev/sl/" -e "s/\([0-9]\+x[0-9]\+\)x[0-9]\+/\1/" -e "s/tstep/${PERIOD}/")
	DIR_SL_IN=${DIR_OUT}
	
	./vint.sh ${START_DATE} ${ENDPP_DATE} \
	    ${DIR_IN} ${DIR_SL_IN} \
	    ${DIR_OUT} \
	    ${OVERWRITE} ${VAR} || exit 1
    done
done


########## 3. zonal mean ##########
#
DIR_IN_LIST=( )
PDEF=$( get_pdef ${PDEF_LEVELS_RED[0]} ) || exit 1
for KEY in isccp ll ml_zlev ml_plev ol sl ; do
    for HGRID in ${HGRID_LIST[@]} ; do
	[ "$( echo ${HGRID} | sed -e "s/[0-9]\+x[0-9]\+//" )" != "" ] && continue
#	for TGRID in ${TGRID_LIST[@]} ; do
	for TGRID in tstep ; do
	    for DIR_IN in \
		../${KEY}/${HGRID}/${TGRID}               \
		../${KEY}/${HGRID}x${ZDEF_NAT}/${TGRID}   \
		../${KEY}/${HGRID}x${ZDEF_ISCCP}/${TGRID} \
		../${KEY}/${HGRID}x3/${TGRID}             \
		../${KEY}/${HGRID}x${PDEF}/${TGRID} ; do
		[ -d ${DIR_IN} ] && DIR_IN_LIST=( ${DIR_IN_LIST[@]} ${DIR_IN} )
	    done
	done
    done
done
for DIR_IN in ${DIR_IN_LIST[@]} ; do
    [ ! -d ${DIR_IN} ] && continue
    VARS_TSTEP_3=( $( expand_vars ${#VARS_TSTEP_3[@]} ${VARS_TSTEP_3[@]} ) )
    VARS_TEMP=( ${VARS_TSTEP_3[@]} )
    VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
                           ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) )
    for VAR in ${VARS_TEMP[@]} ; do
	VAR_CHILD=$( ls --color=never ${DIR_IN} 2>/dev/null | grep ^${VAR}$ )
	[ "${VAR_CHILD}" != "${VAR}" ] && continue
	#
	INPUT_CTL=${DIR_IN}/${VAR}/${VAR}.ctl
	PERIOD=$( tstep_2_period ${INPUT_CTL} ) || exit 1
	DIR_IN_NEW=$( echo ${DIR_IN} | sed -e "s|/tstep$|/${PERIOD}|" )
	#DIR_IN_NEW=${DIR_IN%tstep}${PERIOD}
	#
	DIR_OUT=$( conv_dir ${DIR_IN_NEW} XDEF=ZMEAN ) || exit 1
	./zonal_mean.sh ${START_DATE} ${ENDPP_DATE} \
	    ${DIR_IN_NEW} ${DIR_OUT} \
	    ${OVERWRITE} ${VAR} || exit 1
	#
	RESULT=$( diff ${DIR_IN_NEW}/${VAR}/${VAR}.ctl ${DIR_IN_NEW}/../tstep/${VAR}/${VAR}.ctl ) || exit 1
	if [ "${RESULT}" = "" ] ; then
	    mkdir -p ${DIR_OUT}/../tstep
	    cd ${DIR_OUT}/../tstep
	    [ ! -d ${VAR} -a ! -L ${VAR} ] && ln -s ../${PERIOD}/${VAR}
	    cd - > /dev/null
	fi
    done
done 

########## 4. meridional mean ##########
#


#    ######### 5. regional/global mean (for sl) #########
#    #
#    # native
#    DIR_IN_LIST=( )
#    for KEY in sl ; do
#        # except mean data
#        [ ! -d ../${KEY} ] && continue
#        DIR_IN_LIST=( ${DIR_IN_LIST[@]} \
#                      $( ls ../${KEY} | grep -v mean \
#	                 | sed -e "s|^|../${KEY}/|" \
#	                 | sed -e "s|$|/tstep|" ) )
#    done
#    for DIR_IN in ${DIR_IN_LIST[@]} ; do
#        [ ! -d ${DIR_IN} ] && continue
#	VARS_TSTEP_5=( $( expand_vars ${#VARS_TSTEP_5[@]} ${VARS_TSTEP_5[@]} ) )
#	VARS_TEMP=( ${VARS_TSTEP_5[@]} )
#	#[ "${VARS_TSTEP_5[0]}" = "ALL" ] && VARS_TEMP=( `ls ${DIR_IN}` )
#	VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
#                               ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) )
#	for VAR in ${VARS_TEMP[@]} ; do
#	    VAR_CHILD=$( ls --color=never ${DIR_IN} 2>/dev/null | grep ^${VAR}$ )
#	    [ "${VAR_CHILD}" != "${VAR}" ] && continue
#            for(( i=0; $i<=${#REG_NAME[@]}-1; i=$i+1 )) ; do
#	        DIR_OUT=$( conv_dir ${DIR_IN} XYDEF=rmean/${REG_NAME[$i]} ) || exit 1
#		./reg_mean.sh ${TID} \
#		    ${DIR_IN} ${DIR_OUT} \
#		    ${REG_DOMAIN[$i]} ${OVERWRITE} \
#		    all dummy ${VAR} || exit 1
#		./reg_mean.sh ${TID} \
#		    ${DIR_IN} ${DIR_OUT}_only_land \
#		    ${REG_DOMAIN[$i]} ${OVERWRITE} \
#		    only-land ${VEGET} ${VAR} || exit 1
#		./reg_mean.sh ${TID} \
#		    ${DIR_IN} ${DIR_OUT}_only_ocean \
#		    ${REG_DOMAIN[$i]} ${OVERWRITE} \
#		    only-ocean ${VEGET} ${VAR} || exit 1
#	    done
#	done
#    done

#done  # TID loop



# run twiece or more if time-mean data are necessary for the analysis
#############################################################
# Basic Analysis (time-mean or time-skipped)
#
# whether snapshot or mean
#   *_tstep : following tstep file name (e.g. sa: mean  ss: snapshot)
#   *_mean  : always mean
#
# TODO: rmean
#############################################################
for PERIOD in ${TGRID_LIST[@]} ; do
    [ "${PERIOD}" = "tstep" -o "${PERIOD:0:5}" = "clim_" ] && continue
    #
    echo "############################################################"
    echo "# Basic Analysis (${PERIOD})"
    echo "############################################################"
    echo "#"
    #
    DIR_IN_LIST=( )
    PDEF=$( get_pdef ${PDEF_LEVELS_RED[0]} ) || exit 1
    for KEY in ${KEY_LIST[@]} ; do
	for HGRID in ${HGRID_LIST[@]} ; do
	    for DIR_IN in \
		../../${KEY}/${HGRID}/tstep                \
		../../${KEY}/${HGRID}x${ZDEF_NAT}/tstep    \
		../../${KEY}/${HGRID}x${ZDEF_ISCCP}/tstep  \
		../../${KEY}/${HGRID}x3/tstep              \
		../../${KEY}/${HGRID}x49/tstep             \
		../../${KEY}/${HGRID}x${PDEF}/tstep        \
		../../${KEY}/${HGRID}/tstep/step4          \
		../../${KEY}/${HGRID}/tstep/sta_tra        \
		; do
		[ -d ${DIR_IN} ] && DIR_IN_LIST=( ${DIR_IN_LIST[@]} ${DIR_IN} )
	    done
	done
    done
    #
    for DIR_IN in ${DIR_IN_LIST[@]} ; do
	[ ! -d ${DIR_IN} ] && continue
	VARS_TEMP=( ${VARS[@]} )
	VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
	                       ${#VARS[@]}       ${VARS[@]} ) )
	for VAR in ${VARS_TEMP[@]} ; do
	    VAR_CHILD=$( ls --color=never ${DIR_IN} 2>/dev/null | grep ^${VAR}$ )
	    [ "${VAR_CHILD}" != "${VAR}" ] && continue
	    DIR_OUT=$( conv_dir ${DIR_IN} TDEF=${PERIOD} ) || exit 1
	    if [ "${PERIOD}" = "monthly_mean" ] ; then
		./monthly_mean3.sh ${START_DATE} ${ENDPP_DATE} \
		    ${DIR_IN} ${DIR_OUT} \
		    ${OVERWRITE} ${VAR} || exit 1
#		./monthly_mean2.sh ${START_DATE} ${ENDPP_DATE} \
#		    ${DIR_IN} ${DIR_OUT} \
#		    ${OVERWRITE} ${VAR} || exit 1
	    else
#		./multi_step2.sh ${START_DATE} ${ENDPP_DATE} \
#		    ${DIR_IN} ${DIR_OUT} \
#		    ${PERIOD} ${OVERWRITE} ${VAR} || exit 1
		SA=
		[ "${VAR}" = "zonal" -o "${VAR}" = "vint" -o "${VAR}" = "gmean" ] && SA="s"
		./multi_step3.sh ${START_DATE} ${ENDPP_DATE} \
		    ${DIR_IN} ${DIR_OUT} \
		    ${PERIOD} ${OVERWRITE} ${VAR} ${SA} || exit 1
	    fi
	done
    done
done


# run twiece or more if time-mean data are necessary for the analysis
#############################################################
# Basic Analysis (time-mean or time-skipped)
#
# whether snapshot or mean
#   *_tstep : following tstep file name (e.g. sa: mean  ss: snapshot)
#   *_mean  : always mean
#
# TODO: rmean
#############################################################
for PERIOD in ${TGRID_LIST[@]} ; do
    [ "${PERIOD}" != "clim_1dy_mean" ] && continue
    #
    echo "############################################################"
    echo "# Basic Analysis (${PERIOD})"
    echo "############################################################"
    echo "#"
    #
    DIR_IN_LIST=( )
    PDEF=$( get_pdef ${PDEF_LEVELS_RED[0]} ) || exit 1
    for KEY in ${KEY_LIST[@]} ; do
	for HGRID in ${HGRID_LIST[@]} ; do
	    for DIR_IN in \
		../${KEY}/${HGRID}/1dy_mean                \
		../${KEY}/${HGRID}x${ZDEF_NAT}/1dy_mean    \
		../${KEY}/${HGRID}x${ZDEF_ISCCP}/1dy_mean  \
		../${KEY}/${HGRID}x3/1dy_mean              \
		../${KEY}/${HGRID}x49/1dy_mean             \
		../${KEY}/${HGRID}x${PDEF}/1dy_mean        \
		../${KEY}/${HGRID}/1dy_mean/step4          \
		../${KEY}/${HGRID}/1dy_mean/sta_tra        \
		; do
		[ -d ${DIR_IN} ] && DIR_IN_LIST=( ${DIR_IN_LIST[@]} ${DIR_IN} )
	    done
	done
    done
    #
    for DIR_IN in ${DIR_IN_LIST[@]} ; do
	[ ! -d ${DIR_IN} ] && continue
	VARS_TEMP=( ${VARS[@]} )
	VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
	                       ${#VARS[@]}       ${VARS[@]} ) )
	for VAR in ${VARS_TEMP[@]} ; do
	    VAR_CHILD=$( ls --color=never ${DIR_IN} 2>/dev/null | grep ^${VAR}$ )
	    [ "${VAR_CHILD}" != "${VAR}" ] && continue
	    DIR_OUT=$( conv_dir ${DIR_IN} TDEF=${PERIOD} ) || exit 1

	    ./daily_clim.sh ${START_DATE} ${ENDPP_DATE} \
		${DIR_IN} ${DIR_OUT} \
		${OVERWRITE} ${VAR} || exit 1
	done
    done
done



##############################################################
##
## Basic Analysis (monthly-mean)
##
##############################################################
#VARS_CLIM=( $( expand_vars ${#VARS_CLIM[@]} ${VARS_CLIM[@]} ) )
#if [ "${VARS_CLIM[0]}" != "" ] ; then
#    echo "############################################################"
#    echo "# Basic Analysis (monthly climatology)"
#    echo "#   ${CLIM_START_YEAR}/${CLIM_START_MONTH} - ${CLIM_END_YEAR}/${CLIM_END_MONTH}"
#    echo "############################################################"
#    echo "#"
#
#    DIR_IN_LIST=( )
#    for KEY in isccp ll ml_plev ml_zlev ol sl
#    do
#        [ ! -d ../${KEY} ] && continue
#	DIR_IN_LIST=( ${DIR_IN_LIST[@]} \
#	              `ls ../${KEY} | grep -v rmean | sed -e "s|^|../${KEY}/|" | sed -e "s|$|/monthly_mean|"` )
#	[ -d ../${KEY}/rmean ] && \
#	    DIR_IN_LIST=( ${DIR_IN_LIST[@]} \
#	              `ls ../${KEY}/rmean | sed -e "s|^|../${KEY}/rmean/|" | sed -e "s|$|/monthly_mean|"` )
#    done
#    for DIR_IN in ${DIR_IN_LIST[@]}
#    do
#        [ ! -d ${DIR_IN} ] && continue
#	VARS_TEMP=( ${VARS_CLIM[@]} )
#	[ "${VARS_CLIM[0]}" = "ALL" ] && VARS_TEMP=( `ls ${DIR_IN}` )
#	VARS_TEMP=( `dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
#                             ${#VARS[@]}       ${VARS[@]}` )
#	for VAR in ${VARS_TEMP[@]}
#	do
#	    VAR_CHILD=$( ls --color=never ${DIR_IN} | grep ^${VAR}$ )
#	    [ "${VAR_CHILD}" != "${VAR}" ] && continue
#	    CLIM_START_MONTH2="${CLIM_START_MONTH}"
#	    [ ${CLIM_START_MONTH} -lt 10 ] && CLIM_START_MONTH2="0${CLIM_START_MONTH}"
#	    CLIM_END_MONTH2="${CLIM_END_MONTH}"
#	    [ ${CLIM_END_MONTH} -lt 10 ] && CLIM_END_MONTH2="0${CLIM_END_MONTH}"
#
#	    DIR_OUT=$( conv_dir ${DIR_IN} TDEF=clim/${CLIM_START_YEAR}${CLIM_START_MONTH2}_${CLIM_END_YEAR}${CLIM_END_MONTH2}/monthly_mean ) || exit 1
#
#	    ./monthly_clim.sh ${CLIM_START_YEAR} ${CLIM_START_MONTH} \
#		              ${CLIM_END_YEAR} ${CLIM_END_MONTH} \
#		              ${DIR_IN} ${DIR_OUT} \
#		              ${OVERWRITE} ${VAR} || exit 1
#	done
#    done
#fi



#############################################################
#
# Advanced Analysis (time depends on analysis)
#
#############################################################
VARS_ADV=( $( expand_vars ${#VARS_ADV[@]} ${VARS_ADV[@]} ) )
VARS_ADV=( $( dep_var ${#VARS_ADV[@]} ${VARS_ADV[@]} \
                      ${#VARS[@]}     ${VARS[@]} ) )
#for DAYS in ${DAYS_LIST_ADV[@]} ; do
#for TID in ${TID_LIST_ADV[@]} ; do
echo "############################################################"
echo "# Advanced Analysis"
echo "#   TID = ${TID}"
echo "############################################################"
echo "#"
for VAR in ${VARS_ADV[@]} ; do

    ########## COSP ##########
    #
    if [ "${VAR}" = "cosp" ] ; then
	DIR_IN_ML=../ml_zlev/${XDEF_NAT}x${YDEF_NAT}x${ZDEF_NAT}/tstep
	DIR_IN_SL=../sl/${XDEF_NAT}x${YDEF_NAT}/3hr_tstep
	TOPOG=../../used_database/topog/${XDEF_NAT}x${YDEF_NAT}/topog2.grd
	VGRID_TXT=../../used_database/vgrid/vgrid40.txt
	DIR_OUT=../advanced/cosp_v1.3/${XDEF_NAT}x${YDEF_NAT}/tstep/step4
	STEP=$( echo "${XDEF_NAT} / 640" | bc )
	./advanced/cosp_v1.3.sh ${START_DATE} ${ENDPP_DATE} \
	    ${DIR_IN_ML} ${DIR_IN_SL} ${TOPOG} ${VGRID_TXT} ${DIR_OUT} \
	    ${STEP} ${OVERWRITE} || exit 1
	
	./advanced/cosp_v1.3_rs_radarcld.sh ${START_DATE} ${ENDPP_DATE} \
	    ${DIR_OUT} 30 ${OVERWRITE} || exit 1
    fi
    

    ########## pdf ##########
    #
    if [ "${VAR}" = "pdf_5dy" ] ; then
	./advanced/pdf.sh 5dy_mean ${DAYS} ${OVERWRITE} || exit 1
    fi

    ########## MIM ##########
    #
    if [ "${VAR}" = "mim" ] ; then
	MIM="MIM-0.36r2"
	./advanced/mim_ps.sh ${START_DATE} ${ENDPP_DATE} \
	    ../ml_zlev/144x72x38/tstep \
	    ../advanced/MIM_ps/144x72/tstep \
	    ${PDEF_LEVELS_RED[0]} \
	    ${OVERWRITE} || exit 1

	./advanced/mim.sh ${MIM} ${START_DATE} ${ENDPP_DATE} \
	    ../ml_plev/144x72x18/tstep \
	    ../sl/144x72/6hr_tstep \
	    ../advanced/${MIM}/zmean_72x18/tstep/sta_tra \
	    ${PDEF_LEVELS_RED[0]} \
	    ${OVERWRITE} || exit 1

    fi

    ########## rain_from_cloud ##########
    #
    if [ "${VAR}" = "rain_from_cloud" ] ; then
	./advanced/rain_from_cloud.sh ${DAYS} \
	    ../sl/2560x1280/3hr_tstep \
	    ../isccp/2560x1280x49/tstep \
	    ../advanced/rain_from_cloud/2560x1280/tstep \
	    ${OVERWRITE} || exit 1
    fi
    
    ########## cloud_cape ##########
    #
    if [ "${VAR}" = "cloud_cape" ] ; then
	./advanced/cloud_cape/cloud_cape.sh ${DAYS} \
	    ${OVERWRITE} || exit 1
    fi
    
done

exit


#
YEAR=${START_YEAR_ADV}
MONTH=${START_MONTH_ADV}
while [ ${YEAR} = ${YEAR} -a "${VARS_ADV[0]}" != "" ] ; do
    echo "############################################################"
    echo "# Advanced Analysis"
    echo "#   YM = ${YEAR}/${MONTH}"
    echo "############################################################"
    echo "#"
    for VAR in ${VARS_ADV[@]} ; do

        ########## pdf ##########
	#
	if [ "${VAR}" = "pdf_monthly" ] ; then
	    ./advanced/pdf.sh monthly_mean ${YEAR} ${MONTH} ${OVERWRITE} || exit 1
	fi

    done

    # loop end
    [ ${YEAR} = ${END_YEAR} -a ${MONTH} = ${END_MONTH} ] && break
    MONTH=$( expr ${MONTH} + 1 ) || exit 1
    if [ ${MONTH} = 13 ] ; then
	MONTH=1
	YEAR=$( expr ${YEAR} + 1 ) || exit 1
    fi
done


echo "$0 normally finished"
date
