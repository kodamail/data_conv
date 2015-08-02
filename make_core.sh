#!/bin/sh
#
# Flexible analysis system for NICAM (and various type of) output
#
# TODO: support z->p for native grid (such as for gl06)
# TODO: complex configure (e.g. using namelist-like syntax)
# TODO: when monthly-mean or zonal-mean, if most (>90%) of the values are undef, then the resulting mean value should be set to undef, like legacy data_conv
# TODO: create land/sea mask from la_tg (undef -> ocean)
#
. ./common.sh     || exit 1

JOB=$1
[ ! -f "${JOB}" ] && { echo "error: ${JOB} does not exist." ; exit 1 ; }

echo "$0 started."
date
#############################################################
# load job
#############################################################
. ${JOB}

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

echo "############################################################"
echo "#"
echo "# Basic Analysis (tstep)"
echo "#"
echo "############################################################"
echo "#"
########## 1. reduce grid ##########
#
DIR_IN_LIST=( \
    ../../isccp/${XDEF_NAT}x${YDEF_NAT}x${ZDEF_ISCCP}/tstep \
    ../../ll/${XDEF_NAT}x${YDEF_NAT}/tstep                  \
    ../../ml_zlev/${XDEF_NAT}x${YDEF_NAT}x${ZDEF_NAT}/tstep \
    ../../ol/${XDEF_NAT}x${YDEF_NAT}/tstep                  \
    ../../sl/${XDEF_NAT}x${YDEF_NAT}/tstep                  \
    )
#    ../../isccp/${XDEF_NAT}x${YDEF_NAT}x3/tstep \
for DIR_IN in ${DIR_IN_LIST[@]} ; do
    [ ! -d ${DIR_IN} ] && continue
    #
    VARS_TSTEP_1=( $( expand_vars ${#VARS_TSTEP_1[@]} ${VARS_TSTEP_1[@]} ) )
    VARS_TEMP=( ${VARS_TSTEP_1[@]} )
    VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
	        ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]}) )

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
	    ./reduce_grid2.sh ${START_YMD} ${ENDPP_YMD} \
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
	./z2pre.sh ${START_YMD} ${ENDPP_YMD} \
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


#    #
#    # one pressure level in high horizontal resolution -> use multiple-configure instead!
#    #

#
# omega velocity in low horizontal resolution
#
DIR_IN_LIST=( )
PDEF=$( get_pdef ${PDEF_LEVELS_RED[0]} ) || exit 1
for KEY in ml_plev ; do
    for HGRID in ${HGRID_LIST[@]} ; do
	[ "$( echo ${HGRID} | sed -e "s/[0-9]\+x[0-9]\+//" )" != "" ] && continue
	for TGRID in tstep ; do
	    if [ ${PDEF} -eq 1 ] ; then
		for DIR_INOUT in ../../${KEY}/${HGRID}_p${PDEF_LEVELS_RED[0]}/${TGRID} ; do
		    [ -d ${DIR_INOUT} ] && DIR_INOUT_LIST=( ${DIR_INOUT_LIST[@]} ${DIR_INOUT} )
		done
	    else
		for DIR_INOUT in ../../${KEY}/${HGRID}x${PDEF}/${TGRID} ; do
		    [ -d ${DIR_INOUT} ] && DIR_INOUT_LIST=( ${DIR_INOUT_LIST[@]} ${DIR_INOUT} )
		done
	    fi
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
#	./plev_omega.sh ${START_YMD} ${ENDPP_YMD} \
#	    ${DIR_INOUT_NEW} \
#	    ${PDEF_LEVELS_RED[0]} ms_w ms_rho none none ${OVERWRITE} || exit 1
	./plev_omega.sh ${START_YMD} ${ENDPP_YMD} \
	    ${DIR_INOUT_NEW} \
	    ${PDEF_LEVELS_RED[0]} ms_w none ms_tem ${OVERWRITE} || exit 1
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
	echo "error! plev_z.sh should be re-written!"
	exit 1
	./plev_z.sh ${START_YMD} ${ENDPP_YMD} \
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
	echo "error! vint.sh should be re-written!"
	exit 1
	./vint.sh ${START_YMD} ${ENDPP_YMD} \
	    ${DIR_IN} ${DIR_SL_IN} \
	    ${DIR_OUT} \
	    ${OVERWRITE} ${VAR} || exit 1
    done
done


########## 2.9 ISCCP special ##########
# to create 3-category tstep data
#
DIR_IN_LIST=( )
#PDEF=$( get_pdef ${PDEF_LEVELS_RED[0]} ) || exit 1
for KEY in isccp ; do
    for HGRID in ${HGRID_LIST[@]} ; do
	[ "$( echo ${HGRID} | sed -e "s/[0-9]\+x[0-9]\+//" )" != "" ] && continue
	for TGRID in tstep ; do
	    for DIR_INPUT in ../../${KEY}/${HGRID}x${ZDEF_ISCCP}/${TGRID} ; do
		[ -d ${DIR_INPUT} ] && DIR_IN_LIST=( ${DIR_IN_LIST[@]} ${DIR_INPUT} )
	    done
	done
    done
done
for DIR_IN in ${DIR_IN_LIST[@]} ; do
    [ ! -d ${DIR_IN} ] && continue
    VARS_TSTEP_2_9=( $( expand_vars ${#VARS_TSTEP_2_9[@]} ${VARS_TSTEP_2_9[@]} ) )
    VARS_TEMP=( ${VARS_TSTEP_2_9[@]} )
    VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
	        ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) )
    for VAR in ${VARS_TEMP[@]} ; do
	[ "${VAR}" != "dfq_isccp2" ] && continue
	#
	INPUT_CTL=${DIR_IN}/${VAR}/${VAR}.ctl
	PERIOD=$( tstep_2_period ${INPUT_CTL} ) || exit 1
	DIR_IN_NEW=$( echo ${DIR_IN} | sed -e "s|/tstep$|/${PERIOD}|" )
	#
#	DIR_OUT=$( conv_dir ${DIR_OUT} ZDEF=3 ) || exit 1
	DIR_OUT=$( conv_dir ${DIR_IN_NEW} ZDEF=3 ) || exit 1
	./isccp_3cat.sh ${START_YMD} ${ENDPP_YMD} \
	    ${DIR_IN_NEW} ${DIR_OUT} \
	    ${OVERWRITE} || exit 1
	    
	RESULT=$( diff ${DIR_IN_NEW}/${VAR}/${VAR}.ctl ${DIR_IN_NEW}/../tstep/${VAR}/${VAR}.ctl ) || exit 1
	if [ "${RESULT}" = "" ] ; then
	    mkdir -p ${DIR_OUT}/../tstep
	    cd ${DIR_OUT}/../tstep
	    [ ! -d ${VAR} -a ! -L ${VAR} ] && ln -s ../${PERIOD}/${VAR}
	    cd - > /dev/null
	fi
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
		../../${KEY}/${HGRID}/${TGRID}               \
		../../${KEY}/${HGRID}x${ZDEF_NAT}/${TGRID}   \
		../../${KEY}/${HGRID}x${ZDEF_ISCCP}/${TGRID} \
		../../${KEY}/${HGRID}x3/${TGRID}             \
		../../${KEY}/${HGRID}x${PDEF}/${TGRID} ; do
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
	./zonal_mean.sh ${START_YMD} ${ENDPP_YMD} \
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
	    TMP_LIST=( \
		../../${KEY}/${HGRID}/tstep                \
		../../${KEY}/${HGRID}x${ZDEF_NAT}/tstep    \
		../../${KEY}/${HGRID}x${ZDEF_ISCCP}/tstep  \
		../../${KEY}/${HGRID}x3/tstep              \
		../../${KEY}/${HGRID}x49/tstep             \
		../../${KEY}/${HGRID}/tstep/step4          \
		../../${KEY}/${HGRID}/tstep/sta_tra        \
		)
	    if [ ${PDEF} -eq 1 ] ; then
		TMP_LIST=( ${TMP_LIST[@]} \
		    ../../${KEY}/${HGRID}_p${PDEF_LEVELS_RED[0]}/${TGRID} )
	    else
		TMP_LIST=( ${TMP_LIST[@]} \
		    ../../${KEY}/${HGRID}x${PDEF}/tstep )
	    fi

	    for DIR_IN in ${TMP_LIST[@]} ; do
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
		./monthly_mean3.sh ${START_YMD} ${ENDPP_YMD} \
		    ${DIR_IN} ${DIR_OUT} \
		    ${OVERWRITE} ${VAR} || exit 1
	    else
		SA=
		[ "${VAR}" = "zonal" -o "${VAR}" = "vint" -o "${VAR}" = "gmean" ] && SA="s"
		echo "error! multi_step3.sh should be re-written!"
		exit 1
		./multi_step3.sh ${START_YMD} ${ENDPP_YMD} \
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

	    echo "error! daily_clim.sh should be re-written!"
	    exit 1
	    ./daily_clim.sh ${START_YMD} ${ENDPP_YMD} \
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

echo "$0 normally finished."
date
