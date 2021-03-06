#!/bin/sh
#
# Flexible analysis system for NICAM (and various type of) output
#
CNFID=$1
JOB=$2

echo "$0 started."
export LANG=C
date

. ./common.sh ${CNFID} || exit 1

#############################################################
#
# Load job
#
#############################################################
[[ ! -f "${JOB}" ]] && { echo "error: ${JOB} does not exist." >&2 ; exit 1 ; }
. ${JOB} || exit 1

#############################################################
#
# Overwrite variable in the job
#
#############################################################
while [[ -n "$3" ]] ; do
    eval $3
    shift
done

#############################################################
#
# Expand VARS
#
#############################################################
VARS=( $( expand_vars ${#VARS[@]} ${VARS[@]} ) ) || exit 1

#############################################################
#
# Basic Analysis (tstep)
#
#############################################################
VARS_TSTEP=()
for TGRID in ${TGRID_LIST[@]} ; do
    if [ "${TGRID}" = "tstep" ] ; then
	VARS_TSTEP=( all )  # default variables
	VARS_TSTEP=( $( expand_vars ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) ) || exit 1
	VARS_TSTEP=( $( dep_var     ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} \
                                    ${#VARS[@]}       ${VARS[@]} ) ) || exit 1
	echo "############################################################"
	echo "#"
	echo "# Basic Analysis (tstep)"
	echo "#"
	echo "############################################################"
	echo "#"
	break
    fi
done  # loop: TGRID
#
########## derived variables for native grid variables ##########
#
VARS_ANA=()
if (( ${FLAG_TSTEP_DERIVE} == 1 )) ; then
    VARS_ANA=( ss_ws10m sa_ws10m ms_ws )
    VARS_ANA=( $( expand_vars ${#VARS_ANA[@]}   ${VARS_ANA[@]} ) ) || exit 1
    VARS_ANA=( $( dep_var     ${#VARS_ANA[@]}   ${VARS_ANA[@]} \
                              ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) ) || exit 1
fi
DIR_IN_LIST=()
for DIR_IN in \
    ${DCONV_TOP_RDIR}/sl/${XDEF_NAT}x${YDEF_NAT}/tstep           \
    ${DCONV_TOP_RDIR}/ml_plev/${XDEF_NAT}x${YDEF_NAT}x*/tstep    \
    ; do
    [[ -d "${DIR_IN}" ]] && DIR_IN_LIST+=( ${DIR_IN} )
done
for PDEF_LEVELS in ${PDEF_LEVELS_LIST[@]} ; do
    PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1
    [[ ${PDEF} != 1 ]] && continue
    DIR_IN=${DCONV_TOP_RDIR}/ml_plev/${XDEF_NAT}x${YDEF_NAT}_p${PDEF_LEVELS}/tstep
#    [ -d "${DIR_IN}" ] && DIR_IN_LIST=( ${DIR_IN_LIST[@]} ${DIR_IN} )
    [[ -d "${DIR_IN}" ]] && DIR_IN_LIST+=( ${DIR_IN} )
done
for DIR_IN in ${DIR_IN_LIST[@]} ; do
for HGRID  in ${HGRID_LIST[@]}  ; do
    [[ ! "${HGRID}" =~ ^${XDEF_NAT}x${YDEF_NAT}$ ]] && continue
    for VAR in ${VARS_ANA[@]} ; do
	INPUT_CTL_REF=""
	case "${VAR}" in
	    "ss_ws10m") [[ ! -f ${DIR_IN}/ss_u10m/ss_u10m.ctl ]] && continue ;;
	    "sa_ws10m") [[ ! -f ${DIR_IN}/sa_u10m/sa_u10m.ctl ]] && continue ;;
	    "ms_ws")    [[ ! -f ${DIR_IN}/ms_u/ms_u.ctl       ]] && continue ;;
	esac
	DIR_OUT=${DIR_IN}
#	if [[ "${VAR}" = "ms_ws_p850" ]] ; then
#	    DIR_OUT=$( echo "${DIR_IN}" | sed -e "s|/${XDEF_NAT}x${YDEF_NAT}x[0-9]\+/|/${XDEF_NAT}x${YDEF_NAT}_p850/|" )
#	fi
	./derive.sh ${CNFID} ${START_YMD} ${ENDPP_YMD} \
	    ${DIR_IN} ${DIR_OUT} \
	    ${OVERWRITE} ${VAR} || exit 1
	[[ ! -f ${DIR_OUT}/${VAR}/${VAR}.ctl ]] && continue
	PERIOD=$( tstep_2_period ${DIR_OUT}/${VAR}/${VAR}.ctl ) || exit 1
	mkdir -p ${DIR_OUT}/../${PERIOD}
	if [[ ! -d ${DIR_OUT}/../${PERIOD}/${VAR} ]] ; then
	    mv ${DIR_OUT}/${VAR} ${DIR_OUT}/../${PERIOD}/ || exit 1
	    cd ${DIR_OUT} || exit 1
	    ln -s ../${PERIOD}/${VAR} || exit 1
	    cd - > /dev/null || exit 1
	fi
    done  # loop: VAR
done  # loop: HGRID
done  # loop: DIR_IN
#
########## reduce grid ##########
#
VARS_ANA=()
if (( ${FLAG_TSTEP_REDUCE} == 1 )) ; then
    VARS_ANA=( all )  # default variables
    VARS_ANA=( $( expand_vars ${#VARS_ANA[@]}   ${VARS_ANA[@]} ) ) || exit 1
    VARS_ANA=( $( dep_var     ${#VARS_ANA[@]}   ${VARS_ANA[@]} \
                              ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) ) || exit 1
fi
DIR_IN_LIST=()
for DIR_IN in \
    ${DCONV_TOP_RDIR}/isccp/${XDEF_NAT}x${YDEF_NAT}x${ZDEF_ISCCP}/tstep \
    ${DCONV_TOP_RDIR}/{ll,ol,sl}/${XDEF_NAT}x${YDEF_NAT}/tstep          \
    ${DCONV_TOP_RDIR}/${ZDEF_TYPE}/${XDEF_NAT}x${YDEF_NAT}x${ZDEF}/tstep \
    ; do
    [[ -d "${DIR_IN}" ]] && DIR_IN_LIST+=( ${DIR_IN} )
done
for PDEF_LEVELS in ${PDEF_LEVELS_LIST[@]} ; do
    PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1
    [[ ${PDEF} != 1 ]] && continue
    DIR_IN=${DCONV_TOP_RDIR}/ml_plev/${XDEF_NAT}x${YDEF_NAT}_p${PDEF_LEVELS}/tstep
    [[ -d "${DIR_IN}" ]] && DIR_IN_LIST+=( ${DIR_IN} )
done
for DIR_IN in ${DIR_IN_LIST[@]} ; do
    for HGRID in ${HGRID_LIST[@]} ; do
	[[ "${HGRID}" =~ ^${XDEF_NAT}x${YDEF_NAT} ]] && continue
#	[[ "${HGRID}" = "${XDEF_NAT}x${YDEF_NAT}" ]] && continue
#	[ "$( echo ${HGRID} | sed -e "s/[0-9]\+x[0-9]\+//" )" != "" ] && continue
#	[[ ! "${HGRID}" =~ ^[0-9]+x[0-9]+(_p850)*$ ]] && continue
	#
	for VAR in ${VARS_ANA[@]} ; do
	    INPUT_CTL=${DIR_IN}/${VAR}/${VAR}.ctl
	    [[ ! -f "${INPUT_CTL}" ]] && continue
	    PERIOD=$( tstep_2_period ${INPUT_CTL} ) || exit 1
	    DIR_IN_NEW=$( echo "${DIR_IN}" | sed -e "s|/tstep$|/${PERIOD}|" ) || exit 1
	    DIR_OUT=$( conv_dir ${DIR_IN_NEW} XYDEF=${HGRID} ) || exit 1
	    #
	    ./reduce_grid.sh ${CNFID} ${START_YMD} ${ENDPP_YMD} \
		${DIR_IN_NEW} ${DIR_OUT} \
		${HGRID} ${OVERWRITE} ${VAR} || exit 1
	    #
	    mkdir -p ${DIR_OUT}/../tstep || exit  1
	    cd ${DIR_OUT}/../tstep || exit 1
	    [[ ! -d "${VAR}" && ! -L "${VAR}" ]] && ln -s ../${PERIOD}/${VAR}
	    cd - > /dev/null || exit 1
	done
    done
done
#
########## z -> p ##########
#
# multi pressure levels in low horizontal resolution
# (including p on z -> z on p)
#
VARS_ANA=()
if (( ${FLAG_TSTEP_Z2PRE} == 1 )) ; then
    VARS_ANA=( ml ms_omega ma_omega )  # default variables
    VARS_ANA=( $( expand_vars ${#VARS_ANA[@]}   ${VARS_ANA[@]} ) ) || exit 1
    VARS_ANA=( $( dep_var     ${#VARS_ANA[@]}   ${VARS_ANA[@]} \
                              ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) ) || exit 1
fi
DIR_IN_LIST=()
for HGRID in ${HGRID_LIST[@]} ; do
    [[ "$( echo ${HGRID} | sed -e "s/[0-9]\+x[0-9]\+//" )" != "" ]] && continue
    DIR_IN=${DCONV_TOP_RDIR}/ml_zlev/${HGRID}x${ZDEF}/tstep
    [[ -d "${DIR_IN}" ]] && DIR_IN_LIST+=( ${DIR_IN} )
done
for DIR_IN in ${DIR_IN_LIST[@]} ; do
    for VAR in ${VARS_ANA[@]} ; do
	if [[ "${VAR:3}" = "z" ]] ; then
	    INPUT_CTL=${DIR_IN}/m${VAR:1:1}_pres/m${VAR:1:1}_pres.ctl
	else
	    INPUT_CTL=${DIR_IN}/${VAR}/${VAR}.ctl
	fi
	[[ ! -f "${INPUT_CTL}" ]] && continue
	PERIOD=$( tstep_2_period ${INPUT_CTL} ) || exit 1
	DIR_IN_NEW=$( echo ${DIR_IN} | sed -e "s|/tstep$|/${PERIOD}|" ) || exit 1
	#
	for PDEF_LEVELS in ${PDEF_LEVELS_LIST[@]} ; do
	    PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1
	    DIR_OUT=$( conv_dir ${DIR_IN_NEW} TAG=ml_plev ) || exit 1
	    if (( ${PDEF} == 1 )) ; then
		DIR_OUT=$( conv_dir ${DIR_OUT} ZLEV=${PDEF_LEVELS} ) || exit 1
	    else
		DIR_OUT=$( conv_dir ${DIR_OUT} ZDEF=${PDEF} ) || exit 1
	    fi
	    #
	    if [[ "${VAR:3}" = "z" ]] ; then
		./plev_z.sh ${CNFID} ${START_YMD} ${ENDPP_YMD} \
		    ${DIR_IN_NEW} ${DIR_OUT} \
		    ${PDEF_LEVELS} ${OVERWRITE} ${VAR} || exit 1
	    else
		./z2pre.sh ${CNFID} ${START_YMD} ${ENDPP_YMD} \
		    ${DIR_IN_NEW} ${DIR_OUT} \
		    ${PDEF_LEVELS} ${OVERWRITE} ${VAR} || exit 1
	    fi
	    #
	    mkdir -p ${DIR_OUT}/../tstep || exit 1
	    cd ${DIR_OUT}/../tstep || exit 1
	    [[ ! -d "${VAR}" && ! -L "${VAR}" ]] && ln -s ../${PERIOD}/${VAR}
	    cd - > /dev/null || exit 1
	done
    done
done
#
# omega velocity on pressure level
#
VARS_ANA=()
if (( ${FLAG_TSTEP_PLEVOMEGA} == 1 )) ; then
    VARS_ANA=( ms_omega ma_omega )
    VARS_ANA=( $( expand_vars ${#VARS_ANA[@]}   ${VARS_ANA[@]} ) ) || exit 1
    VARS_ANA=( $( dep_var     ${#VARS_ANA[@]}   ${VARS_ANA[@]} \
                              ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) ) || exit 1
fi
DIR_INOUT_LIST=()
PDEF_LEVELS_IN_LIST=()
PDEF=$( get_pdef ${PDEF_LEVELS_LIST[0]} ) || exit 1
for HGRID in ${HGRID_LIST[@]} ; do
    [[ "$( echo ${HGRID} | sed -e "s/[0-9]\+x[0-9]\+//" )" != "" ]] && continue
    for PDEF_LEVELS in ${PDEF_LEVELS_LIST[@]} ; do
	PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1
	if (( ${PDEF} == 1 )) ; then
	    DIR_INOUT=${DCONV_TOP_RDIR}/ml_plev/${HGRID}_p${PDEF_LEVELS}/tstep
	else
	    DIR_INOUT=${DCONV_TOP_RDIR}/ml_plev/${HGRID}x${PDEF}/tstep
	fi
	if [[ -d "${DIR_INOUT}" ]] ; then
	    DIR_INOUT_LIST=( ${DIR_INOUT_LIST[@]} ${DIR_INOUT} )
	    #PDEF_LEVELS_IN_LIST=( ${PDEF_LEVELS_IN_LIST[@]} ${PDEF_LEVELS} )
	    PDEF_LEVELS_IN_LIST+=( ${PDEF_LEVELS} )
	fi
    done
done
for(( i=0; $i<${#DIR_INOUT_LIST[@]}; i=$i+1 )) ; do
    DIR_INOUT=${DIR_INOUT_LIST[$i]}
    PDEF_LEVELS_IN=${PDEF_LEVELS_IN_LIST[$i]}
    PDEF=$( get_pdef ${PDEF_LEVELS_IN} ) || exit 1
    #
    for VAR in ${VARS_ANA[@]} ; do
	TYPE=${VAR:1:1}
	INPUT_CTL=${DIR_INOUT}/m${TYPE}_w/m${TYPE}_w.ctl
	[[ ! -f "${INPUT_CTL}" ]] && continue
	PERIOD=$( tstep_2_period ${INPUT_CTL} ) || exit 1
	DIR_INOUT_NEW=$( echo ${DIR_INOUT} | sed -e "s|/tstep$|/${PERIOD}|" ) || exit 1
	#
	./plev_omega.sh ${CNFID} ${START_YMD} ${ENDPP_YMD} \
	    ${DIR_INOUT_NEW} \
	    ${PDEF_LEVELS_LIST[0]} m${TYPE}_w none m${TYPE}_tem ${OVERWRITE} || exit 1
	#
	mkdir -p ${DIR_INOUT}/../tstep || exit 1
	cd ${DIR_INOUT}/../tstep || exit 1
	[[ ! -d "${VAR}" && ! -L "${VAR}" ]] && ln -s ../${PERIOD}/${VAR}
	cd - > /dev/null || exit 1
    done
done

##
## vertical integral
##
#    DIR_IN_LIST=( )
#    for KEY in ml_zlev ; do
#	for HGRID in ${HGRID_LIST[@]} ; do
#	    for TGRID in tstep ; do
#		for DIR_IN in ../${KEY}/${HGRID}x${ZDEF_NAT}/${TGRID} ; do
#		    [ -d ${DIR_IN} ] && DIR_IN_LIST=( ${DIR_IN_LIST[@]} ${DIR_IN} )
#		done
#	    done
#	done
#    done
#    for DIR_IN in ${DIR_IN_LIST[@]} ; do
#	[ ! -d ${DIR_IN} ] && continue
#	
#	VARS_TSTEP_2_5=( $( expand_vars ${#VARS_TSTEP_2_5[@]} ${VARS_TSTEP_2_5[@]} ) )
#	VARS_TEMP=( ${VARS_TSTEP_2_5[@]} )
#	#[ "${VARS_TSTEP_2_3[0]}" = "ALL" ] && VARS_TEMP=( $( ls ${DIR_IN} ) )
#	VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
#	    ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) )
#	for VAR in ${VARS_TEMP[@]} ; do
#	    INPUT_CTL=${DIR_IN}/${VAR}/${VAR}.ctl
#	    PERIOD=$( tstep_2_period ${INPUT_CTL} )
#	    DIR_OUT=$( echo "${DIR_IN}" \
#		| sed -e "s/ml_zlev/sl/" -e "s/\([0-9]\+x[0-9]\+\)x[0-9]\+/\1/" -e "s/tstep/${PERIOD}/")
#	    DIR_SL_IN=${DIR_OUT}
#	    echo "error! vint.sh should be re-written!"
#	    exit 1
#	    ./vint.sh ${START_YMD} ${ENDPP_YMD} \
#		${DIR_IN} ${DIR_SL_IN} \
#		${DIR_OUT} \
#		${OVERWRITE} ${VAR} || exit 1
#	done
#    done
#fi


########## 2.9 ISCCP special ##########
# to create 3-category tstep data
#
VARS_ANA=()
if (( ${FLAG_TSTEP_ISCCP3CAT} == 1 )) ; then
    VARS_ANA=( dfq_isccp2 )
    VARS_ANA=( $( expand_vars ${#VARS_ANA[@]}   ${VARS_ANA[@]} ) ) || exit 1
    VARS_ANA=( $( dep_var     ${#VARS_ANA[@]}   ${VARS_ANA[@]} \
                              ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) ) || exit 1
fi
DIR_IN_LIST=()
for HGRID in ${HGRID_LIST[@]} ; do
    [[ "$( echo ${HGRID} | sed -e "s/[0-9]\+x[0-9]\+//" )" != "" ]] && continue
    for DIR_INPUT in ${DCONV_TOP_RDIR}/isccp/${HGRID}x${ZDEF_ISCCP}/tstep ; do
	#[ -d "${DIR_INPUT}" ] && DIR_IN_LIST=( ${DIR_IN_LIST[@]} ${DIR_INPUT} )
	[ -d "${DIR_INPUT}" ] && DIR_IN_LIST+=( ${DIR_INPUT} )
    done
done
for DIR_IN in ${DIR_IN_LIST[@]} ; do
for VAR in ${VARS_ANA[@]} ; do
    INPUT_CTL=${DIR_IN}/${VAR}/${VAR}.ctl
    [[ ! -f "${INPUT_CTL}" ]] && continue
    PERIOD=$( tstep_2_period ${INPUT_CTL} ) || exit 1
    DIR_IN_NEW=$( echo ${DIR_IN} | sed -e "s|/tstep$|/${PERIOD}|" ) || exit 1
    DIR_OUT=$( conv_dir ${DIR_IN_NEW} ZDEF=3 ) || exit 1
    #
    ./isccp_3cat.sh ${CNFID} ${START_YMD} ${ENDPP_YMD} \
	${DIR_IN_NEW} ${DIR_OUT} \
	${OVERWRITE} || exit 1
    #
    mkdir -p ${DIR_OUT}/../tstep || exit 1
    cd ${DIR_OUT}/../tstep || exit 1
    [[ ! -d "${VAR}" && ! -L "${VAR}" ]] && ln -s ../${PERIOD}/${VAR}
    cd - > /dev/null || exit 1
done # loop: VAR
done # loop: DIR_IN


########## zonal mean ##########
#
VARS_ANA=()
if (( ${FLAG_TSTEP_ZM} == 1 )) ; then
    VARS_ANA=( all )
    VARS_ANA=( $( expand_vars ${#VARS_ANA[@]}   ${VARS_ANA[@]} ) ) || exit 1
    VARS_ANA=( $( dep_var     ${#VARS_ANA[@]}   ${VARS_ANA[@]} \
                              ${#VARS_TSTEP[@]} ${VARS_TSTEP[@]} ) ) || exit 1
fi
DIR_IN_LIST=()
for HGRID in ${HGRID_LIST[@]} ; do
    [[ "$( echo ${HGRID} | sed -e "s/[0-9]\+x[0-9]\+//" )" != "" ]] && continue
    for DIR_IN in \
	${DCONV_TOP_RDIR}/{ll,ol,sl}/${HGRID}/tstep      \
	${DCONV_TOP_RDIR}/${ZDEF_TYPE}/${HGRID}x${ZDEF}/tstep \
	${DCONV_TOP_RDIR}/isccp/${HGRID}x{${ZDEF_ISCCP},3}/tstep ; do
	#[ -d "${DIR_IN}" ] && DIR_IN_LIST=( ${DIR_IN_LIST[@]} ${DIR_IN} )
	[[ -d "${DIR_IN}" ]] && DIR_IN_LIST+=( ${DIR_IN} )
    done
    for PDEF_LEVELS in ${PDEF_LEVELS_LIST[@]} ; do
	PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1
	DIR_IN=${DCONV_TOP_RDIR}/ml_plev/${HGRID}x${PDEF}/tstep
	#[ -d "${DIR_IN}" ] && DIR_IN_LIST=( ${DIR_IN_LIST[@]} ${DIR_IN} )
	[[ -d "${DIR_IN}" ]] && DIR_IN_LIST+=( ${DIR_IN} )
    done
done
for DIR_IN in ${DIR_IN_LIST[@]} ; do
for VAR in ${VARS_ANA[@]} ; do
    INPUT_CTL=${DIR_IN}/${VAR}/${VAR}.ctl
    [[ ! -f "${INPUT_CTL}" ]] && continue
    PERIOD=$( tstep_2_period ${INPUT_CTL} ) || exit 1
    DIR_IN_NEW=$( echo ${DIR_IN} | sed -e "s|/tstep$|/${PERIOD}|" ) || exit 1
    DIR_OUT=$( conv_dir ${DIR_IN_NEW} XDEF=ZMEAN ) || exit 1
    #
    ./zonal_mean.sh ${CNFID} ${START_YMD} ${ENDPP_YMD} \
	${DIR_IN_NEW} ${DIR_OUT} \
	${OVERWRITE} ${VAR} || exit 1
    #
    mkdir -p ${DIR_OUT}/../tstep || exit 1
    cd ${DIR_OUT}/../tstep || exit 1
    [[ ! -d "${VAR}" && ! -L "${VAR}" ]] && ln -s ../${PERIOD}/${VAR}
    cd - > /dev/null || exit 1
done  # loop: VAR
done  # loop: DIR_IN

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



#############################################################
# Basic Analysis (time-mean or time-skipped)
#
# whether snapshot or mean
#   *_tstep : following tstep file name (e.g. sa: mean  ss: snapshot)
#   *_mean  : always mean
#
#############################################################
for PERIOD in ${TGRID_LIST[@]} ; do
    [[ "${PERIOD}" == "tstep" || "${PERIOD:0:5}" == "clim_" ]] && continue
    #
    echo "############################################################"
    echo "#"
    echo "# Basic Analysis (${PERIOD})"
    echo "#"
    echo "############################################################"
    echo "#"
    #
    VARS_ANA=( all )
    VARS_ANA=( $( expand_vars ${#VARS_ANA[@]} ${VARS_ANA[@]} ) ) || exit 1
    VARS_ANA=( $( dep_var     ${#VARS_ANA[@]} ${VARS_ANA[@]} \
                              ${#VARS[@]}     ${VARS[@]} ) ) || exit 
    DIR_IN_LIST=()
    for HGRID in ${HGRID_LIST[@]} ; do
	for DIR_IN in \
	    ${DCONV_TOP_RDIR}/{ll,ol,sl}/${HGRID}/tstep          \
	    ${DCONV_TOP_RDIR}/${ZDEF_TYPE}/${HGRID}x${ZDEF}/tstep \
	    ${DCONV_TOP_RDIR}/ml_plev/${HGRID}/tstep \
	    ${DCONV_TOP_RDIR}/${ZDEF_TYPE}/${HGRID}_*/tstep \
	    ${DCONV_TOP_RDIR}/isccp/${HGRID}x{${ZDEF_ISCCP},3}/tstep ;  do
	    [[ -d "${DIR_IN}" ]] && DIR_IN_LIST+=( ${DIR_IN} )
	done
	for PDEF_LEVELS in ${PDEF_LEVELS_LIST[@]} ; do
	    PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1
	    if (( ${PDEF} == 1 )) ; then
		DIR_IN=${DCONV_TOP_RDIR}/ml_plev/${HGRID}_p${PDEF_LEVELS}/tstep
	    else
		DIR_IN=${DCONV_TOP_RDIR}/ml_plev/${HGRID}x${PDEF}/tstep
	    fi
	    [[ -d "${DIR_IN}" ]] && DIR_IN_LIST+=( ${DIR_IN} )
	done
    done
    #
    for DIR_IN in ${DIR_IN_LIST[@]} ; do
    for VAR in ${VARS_ANA[@]} ; do
	[[ ! -f "${DIR_IN}/${VAR}/${VAR}.ctl" ]] && continue
	DIR_OUT=$( conv_dir ${DIR_IN} TDEF=${PERIOD} ) || exit 1
	#
	if [[ "${PERIOD}" == "monthly_mean" ]] ; then
	    ./monthly_mean.sh ${CNFID} ${START_YMD} ${ENDPP_YMD} \
		${DIR_IN} ${DIR_OUT} \
		${OVERWRITE} ${INC_SUBVARS} ${VAR} || exit 1
	else
	    SA=
# -> WHY?		[ "${VAR}" = "zonal" -o "${VAR}" = "vint" -o "${VAR}" = "gmean" ] && SA="s"
#		echo "error! multi_step3.sh should be re-written!"
#		exit 1
	    ./multi_step.sh ${CNFID} ${START_YMD} ${ENDPP_YMD} \
		${DIR_IN} ${DIR_OUT} \
		${PERIOD} ${OVERWRITE} ${INC_SUBVARS} ${VAR} ${SA} || exit 1
	fi
    done  # loop: VAR
    done  # loop: DIR_IN
done


#############################################################
#
# Basic Analysis (after monthly-mean)
#
#############################################################
VARS_MM=()
for TGRID in ${TGRID_LIST[@]} ; do
    if [[ "${TGRID}" == "monthly_mean" ]] ; then
	VARS_MM=( all )  # default variables
	VARS_MM=( $( expand_vars ${#VARS_MM[@]} ${VARS_MM[@]} ) ) || exit 1
	VARS_MM=( $( dep_var     ${#VARS_MM[@]} ${VARS_MM[@]} \
                                 ${#VARS[@]}    ${VARS[@]} ) ) || exit 1
	echo "############################################################"
	echo "#"
	echo "# Basic Analysis (after monthly-mean)"
	echo "#"
	echo "############################################################"
	echo "#"
	break
    fi
done
#
########## zonal mean for monthly-mean data ##########
#
VARS_ANA=()
if (( ${FLAG_MM_ZM} == 1 )) ; then
    VARS_ANA=( all )
    VARS_ANA=( $( expand_vars ${#VARS_ANA[@]} ${VARS_ANA[@]} ) ) || exit 1
    VARS_ANA=( $( dep_var     ${#VARS_ANA[@]} ${VARS_ANA[@]} \
                              ${#VARS_MM[@]}  ${VARS_MM[@]} ) ) || exit 1
fi
DIR_IN_LIST=()
for HGRID in ${HGRID_LIST[@]} ; do
    [[ "$( echo ${HGRID} | sed -e "s/[0-9]\+x[0-9]\+//" )" != "" ]] && continue
    for DIR_IN in \
	${DCONV_TOP_RDIR}/{ll,ol,sl}/${HGRID}/monthly_mean      \
	${DCONV_TOP_RDIR}/${ZDEF_TYPE}/${HGRID}x${ZDEF}/monthly_mean \
	${DCONV_TOP_RDIR}/isccp/${HGRID}x{${ZDEF_ISCCP},3}/monthly_mean ; do
	[[ -d "${DIR_IN}" ]] && DIR_IN_LIST+=( ${DIR_IN} )
    done
    for PDEF_LEVELS in ${PDEF_LEVELS_LIST[@]} ; do
	PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1
	if (( ${PDEF} == 1 )) ; then
	    DIR_IN=${DCONV_TOP_RDIR}/ml_plev/${HGRID}_p${PDEF_LEVELS}/monthly_mean
	else
	    DIR_IN=${DCONV_TOP_RDIR}/ml_plev/${HGRID}x${PDEF}/monthly_mean
	fi
	[[ -d "${DIR_IN}" ]] && DIR_IN_LIST+=( ${DIR_IN} )
    done
done
for DIR_IN in ${DIR_IN_LIST[@]} ; do
for VAR in ${VARS_ANA[@]} ; do
    INPUT_CTL=${DIR_IN}/${VAR}/${VAR}.ctl
    [[ ! -f "${INPUT_CTL}" ]] && continue
#	PERIOD=$( tstep_2_period ${INPUT_CTL} ) || exit 1
#	DIR_IN_NEW=$( echo ${DIR_IN} | sed -e "s|/tstep$|/${PERIOD}|" ) || exit 1
#	DIR_OUT=$( conv_dir ${DIR_IN_NEW} XDEF=ZMEAN ) || exit 1
    DIR_OUT=$( conv_dir ${DIR_IN} XDEF=MMZMEAN ) || exit 1
    #
    ./monthly_zonal_mean.sh ${CNFID} ${START_YMD} ${ENDPP_YMD} \
	${DIR_IN} ${DIR_OUT} \
	${OVERWRITE} ${VAR} || exit 1
done  # loop: VAR
done  # loop: DIR_IN

echo "$0 normally finished."
date
exit

# below to be modified

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
#for PERIOD in ${TGRID_LIST[@]} ; do
#    [ "${PERIOD}" != "clim_1dy_mean" ] && continue
#    #
#    echo "############################################################"
#    echo "# Basic Analysis (${PERIOD})"
#    echo "############################################################"
#    echo "#"
#    #
#    DIR_IN_LIST=( )
#    PDEF=$( get_pdef ${PDEF_LEVELS_LIST[0]} ) || exit 1
#    for KEY in ${KEY_LIST[@]} ; do
#	for HGRID in ${HGRID_LIST[@]} ; do
#	    for DIR_IN in \
#		../${KEY}/${HGRID}/1dy_mean                \
#		../${KEY}/${HGRID}x${ZDEF_NAT}/1dy_mean    \
#		../${KEY}/${HGRID}x${ZDEF_ISCCP}/1dy_mean  \
#		../${KEY}/${HGRID}x3/1dy_mean              \
#		../${KEY}/${HGRID}x49/1dy_mean             \
#		../${KEY}/${HGRID}x${PDEF}/1dy_mean        \
#		../${KEY}/${HGRID}/1dy_mean/step4          \
#		../${KEY}/${HGRID}/1dy_mean/sta_tra        \
#		; do
#		[ -d ${DIR_IN} ] && DIR_IN_LIST=( ${DIR_IN_LIST[@]} ${DIR_IN} )
#	    done
#	done
#    done
#    #
#    for DIR_IN in ${DIR_IN_LIST[@]} ; do
#	[ ! -d ${DIR_IN} ] && continue
#	VARS_TEMP=( ${VARS[@]} )
#	VARS_TEMP=( $( dep_var ${#VARS_TEMP[@]}  ${VARS_TEMP[@]} \
#	                       ${#VARS[@]}       ${VARS[@]} ) )
#	for VAR in ${VARS_TEMP[@]} ; do
#	    VAR_CHILD=$( ls --color=never ${DIR_IN} 2>/dev/null | grep ^${VAR}$ )
#	    [ "${VAR_CHILD}" != "${VAR}" ] && continue
#	    DIR_OUT=$( conv_dir ${DIR_IN} TDEF=${PERIOD} ) || exit 1
#
#	    echo "error! daily_clim.sh should be re-written!"
#	    exit 1
#	    ./daily_clim.sh ${START_YMD} ${ENDPP_YMD} \
#		${DIR_IN} ${DIR_OUT} \
#		${OVERWRITE} ${VAR} || exit 1
#	done
#    done
#done

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

