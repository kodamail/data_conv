#!/bin/bash
#
# zonal mean
#
echo "########## $0 start ##########"
set -x
CNFID=$1       # CNFID (e.g. "def")
START_YMD=$2   # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$3   # YYYYMMDD (end+1 day of analysis period)
INPUT_DIR=$4   # input dir
OUTPUT_DIR=$5  # output dir
OVERWRITE=$6   # overwrite option (optional)
TARGET_VAR=$7  # variable name (optional)
set +x
echo "##########"

source ./common.sh ${CNFID} || exit 1

create_temp || error_exit
TEMP_DIR=${BASH_COMMON_TEMP_DIR}
trap "finish" 0

if [[ ! "${OVERWRITE}" =~ ^(|yes|no|dry-rm|rm)$ ]] ; then
    error_exit "error: OVERWRITE = ${OVERWRITE} is not supported yet."
fi

if [[ "${TARGET_VAR}" = "" ]] ; then
    VAR_LIST=( $( ls ${INPUT_DIR}/ ) ) || error_exit
else
    VAR_LIST=( ${TARGET_VAR} )
fi

NOTHING=1
#============================================================#
#
#  variable loop
#
#============================================================#
for VAR in ${VAR_LIST[@]} ; do
    #
    #----- check whether output dir is write-protected
    #
    if [[ -f "${OUTPUT_DIR}/${VAR}/_locked" ]] ; then
        echo "info: ${OUTPUT_DIR} is locked."
        continue
    fi
#    #
#    #----- check existence of output data
#    #
    mkdir -p ${OUTPUT_DIR}/${VAR}/log
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl

#    YM_STARTMM=$(     date -u --date "${START_YMD} 1 second ago" +%Y%m ) || exit 1
#    YM_END=$( date -u --date "${ENDPP_YMD} 1 month ago"  +%Y%m ) || exit 1
#    if [ -f "${OUTPUT_CTL}" -a "${OVERWRITE}" != "rm" -a "${OVERWRITE}" != "dry-rm" ] ; then
#        YM_TMP=$(     date -u --date "${YM_STARTMM}01 1 month" +%Y%m ) || exit 1
#        FLAG=( $( grads_exist_data.sh ${OUTPUT_CTL} -ymd "[${YM_TMP}15:${YM_END}15]" ) ) || exit 1
#        if [ "${FLAG[0]}" = "ok" ] ; then
#            echo "info: Output data already exist."
#            continue
#        fi
#    fi
    #
    #----- get number of grids for input/output
    #
    INPUT_CTL=${INPUT_DIR}/${VAR}/${VAR}.ctl
    if [[ ! -f "${INPUT_CTL}" ]] ; then
        echo "warning: ${INPUT_CTL} does not exist."
        continue
    fi
    INPUT_CTL_META=$( ctl_meta ${INPUT_CTL} ) || error_exit
    DIMS=( $( grads_ctl.pl ${INPUT_CTL_META} DIMS NUM ) ) || error_exit
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}
    TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    TDEF_START=$(     grads_ctl.pl ${INPUT_CTL_META} TDEF 1 ) || error_exit
    #
    START_HMS=$( date -u --date "${TDEF_START}" +%H%M%S )
    TMP_H=${START_HMS:0:2}
    TMP_M=${START_HMS:2:2}
    let TMP_MN=TMP_H*60+TMP_M
    #
    #----- check existence of input data
    #
    if [[ "${START_HMS}" != "000000" ]] ; then
#	TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${START_YMD} -gt ) || error_exit
#	TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${ENDPP_YMD} -le ) || error_exit
	TMIN=$( grads_ctl.pl ${INPUT_CTL_META} TDEF --target index --value "(${START_YMD}" ) || error_exit
	TMAX=$( grads_ctl.pl ${INPUT_CTL_META} TDEF --target index --value "${ENDPP_YMD}]" ) || error_exit
    else
#	TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${START_YMD} -ge ) || error_exit
#	TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${ENDPP_YMD} -lt ) || error_exit
	TMIN=$( grads_ctl.pl ${INPUT_CTL_META} TDEF --target index --value "[${START_YMD}" ) || error_exit
	TMAX=$( grads_ctl.pl ${INPUT_CTL_META} TDEF --target index --value "${ENDPP_YMD})" ) || error_exit
    fi
    INPUT_DSET_LIST=( $( grads_ctl.pl ${INPUT_CTL} DSET "${TMIN}:${TMAX}" ) ) || error_exit
    INPUT_NC_LIST=()
    for INPUT_DSET in ${INPUT_DSET_LIST[@]} ; do
	INPUT_NC_TMP=${INPUT_DSET/^/${INPUT_CTL_META%/*}\//}
#	echo ${INPUT_NC_TMP}
#	INPUT_NC=$( readlink -e ${INPUT_NC_TMP} ) \
#	    || { echo "error: ${INPUT_NC_TMP} does not exist." ; exit 1 ; }
	INPUT_NC=$( readlink -e ${INPUT_NC_TMP} ) \
	    || { echo "warning: ${INPUT_NC_TMP} does not exist. Skip!" ; continue ; }
	INPUT_NC_LIST+=( ${INPUT_NC} )
    done


#echo ${INPUT_NC_LIST[@]}
#exit 1

#    if [ "${FLAG[0]}" != "ok" ] ; then
#        echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})."
#        continue
#    fi
    #
    #---- generate control file (unified)
    #
#    mkdir -p ${OUTPUT_DIR}/${VAR}/log
    if [[ ! "${OVERWRITE}" =~ ^(dry-rm|rm)$ ]] ; then
	sed ${INPUT_CTL_META} \
	    -e "s|^DSET .*|DSET ^%y4/${VAR}_%y4%m2.nc|" \
	    > ${OUTPUT_CTL}

#	grads_ctl.pl ${INPUT_CTL} > ${OUTPUT_CTL}.tmp1 || exit 1
#        #
#	sed ${OUTPUT_CTL}.tmp1 \
#            -e "/^XDEF/,/^YDEF/{" \
#            -e "/^\(XDEF\|YDEF\)/!D" \
#            -e "}" \
#            -e "s/^XDEF.*/XDEF  1  LEVELS  0.0/" \
#            > ${OUTPUT_CTL} || exit 1
#	rm ${OUTPUT_CTL}.tmp1

    fi

    #
    #========================================#
    #  loop for each file
    #========================================#
#    YM_PREV=-1
    for INPUT_NC in ${INPUT_NC_LIST[@]} ; do
#	TDEF_FILE=$( ${BIN_CDO} -s ntime ${INPUT_NC} )
	# First assume INPUT_NC: ${VAR}_${YM}.nc
	INPUT_NC_TMP=${INPUT_NC##*/}
	INPUT_NC_TMP=${INPUT_NC_TMP%.nc}
	YM=${INPUT_NC_TMP#${VAR}_}
	if [[ ! ${YM} =~ ^[0-9]{6}$ ]] ; then
	    YMD_GRADS=$( grads_ctl.pl ${INPUT_NC} TDEF 1 )
            YM=$( date -u --date "${YMD_GRADS}" +%Y%m ) || error_exit
	fi
#	(( ${YM} == ${YM_PREV} )) && { echo "error: time interval less than 1-dy is not supported now" ; exit 1 ; }
	YEAR=${YM:0:4}
        #
        #----- output data
        #
        # File name convention (YMD = first day)
        #   2004/ms_tem_${YMD}.nc
        #
        OUTPUT_NC=$( readlink -m ${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YM}.nc )
	#
	# check existence of output data
	#
	if [[ -f "${OUTPUT_NC}" ]] ; then
	    [[ ! "${OVERWRITE}" =~ ^(yes|dry-rm|rm)$ ]] && continue
	    echo "Removing ${OUTPUT_NC}." ; echo ""
	    [[ "${OVERWRITE}" = "dry-rm" ]] && continue
	    rm -f ${OUTPUT_NC}
	fi
	[[ "${OVERWRITE}" =~ ^(dry-rm|rm)$ ]] && continue
	#
	mkdir -p ${OUTPUT_NC%/*} || error_exit
	echo "INPUT_NC=${INPUT_NC}"
	NOTHING=0
	#
	cdo -s -b 32 zonmean ${INPUT_NC} ${TEMP_DIR}/tmp.nc || error_exit
	mv ${TEMP_DIR}/tmp.nc ${OUTPUT_NC} || error_exit

    done
done  # loop: VAR

(( ${NOTHING} == 1 )) && echo "info: Nothing to do."
echo "$0 normally finished ($(date))."
echo
