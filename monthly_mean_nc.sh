#!/bin/bash
#
# monthly mean
#
echo "########## $0 start ##########"
set -x
CNFID=$1       # CNFID (e.g. "def")
START_YMD=$2   # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$3   # YYYYMMDD (end+1 day of analysis period)
INPUT_DIR=$4   # input dir
OUTPUT_DIR=$5  # output dir
OVERWRITE=$6   # overwrite option (optional)
INC_SUBVARS=$7 # SUBVARS option (optional)
TARGET_VAR=$8  # variable name (optional)
set +x
echo "##########"

source ./common.sh ${CNFID} || error_exit

create_temp || error_exit
TEMP_DIR=${BASH_COMMON_TEMP_DIR}
trap "finish" 0

[[ ! "${OVERWRITE}" =~ ^(|yes|no|dry-rm|rm)$ ]] \
    && error_exit "error: OVERWRITE = ${OVERWRITE} is not supported yet."

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
    #
    #----- check existence of output data
    #
    YM_STARTMM=$(     date -u --date "${START_YMD} 1 second ago" +%Y%m ) || error_exit
    YM_END=$( date -u --date "${ENDPP_YMD} 1 month ago"  +%Y%m ) || error_exit

##    if [ -f "${OUTPUT_CTL}" ] ; then
#    if [ -f "${OUTPUT_CTL}" -a "${OVERWRITE}" != "rm" -a "${OVERWRITE}" != "dry-rm" ] ; then
#	YM_TMP=$(     date -u --date "${YM_STARTMM}01 1 month" +%Y%m ) || exit 1
#        FLAG=( $( grads_exist_data.sh ${OUTPUT_CTL} -ymd "[${YM_TMP}15:${YM_END}15]" ) ) || exit 1
#        if [ "${FLAG[0]}" = "ok" ] ; then
#            echo "info: Output data already exist."
#            continue
#        fi
#    fi

    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
    mkdir -p ${OUTPUT_DIR}/${VAR} || error_exit

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
    INPUT_TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    (( ${EDEF} > 1 )) && error_exit "EDEF=${EDEF} is not supported"
    INPUT_TDEF_START=$(     grads_ctl.pl ${INPUT_CTL_META} TDEF 1 ) || error_exit
    INPUT_TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_CTL_META} TDEF INC --unit SEC | sed -e "s/SEC//" ) || error_exit
    SUBVARS=( ${VAR} )
    if [[ "${INC_SUBVARS}" = "yes" ]] ; then
	SUBVARS=( $( grads_ctl.pl ${INPUT_CTL_META} VARS ALL ) ) || error_exit
    fi
    VDEF=${#SUBVARS[@]}
    #
    START_HMS=$( date -u --date "${INPUT_TDEF_START}" +%H%M%S )
    TMP_H=${START_HMS:0:2}
    TMP_M=${START_HMS:2:2}
    let TMP_MN=TMP_H*60+TMP_M
    #
    #---- generate control file (unified)
    #
    if [[ ! "${OVERWRITE}" =~ ^(dry-rm|rm)$ ]] ; then
	OUTPUT_TDEF=0
	YM=${YM_STARTMM}
	while (( ${YM} < ${YM_END} )) ; do
	    YM=$( date -u --date "${YM}01 1 month" +%Y%m )
	    let OUTPUT_TDEF=OUTPUT_TDEF+1
	done
	OUTPUT_TDEF_START=15$( date -u --date "${INPUT_TDEF_START}" +%b%Y ) || error_exit
	sed ${INPUT_CTL_META} \
	    -e "s|^DSET .*|DSET ^%y4/${VAR}_%y4%m2.nc|" \
	    -e "/^CHSUB .*/d" \
	    -e "s/^TDEF .*$/TDEF  time  ${OUTPUT_TDEF}  LINEAR  ${OUTPUT_TDEF_START}  1mo/" \
	    > ${OUTPUT_CTL}
    fi
    #
    #========================================#
    #  loop for each year/month
    #========================================#
    YM=${YM_STARTMM}
    while (( ${YM} < ${YM_END} )) ; do
        #
        #----- set/proceed date -----#
        #
	YM=$(   date -u --date "${YM}01 1 month" +%Y%m ) || error_exit
	YMPP=$( date -u --date "${YM}01 1 month" +%Y%m ) || error_exit
        YEAR=${YM:0:4} ; MONTH=${YM:4:2}
        #
        #----- output data
        #
        # File name convention
        #   2004/ms_tem_${YM}.nc
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
	NOTHING=0
        #
        #----- check existence of input data
        #
	if [[ "${START_HMS}" != "000000" ]] ; then
#	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
	    TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${YM}01   -gt ) || error_exit
	    TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${YMPP}01 -le ) || error_exit
	else
#	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "[${START_YMD}:${ENDPP_YMD})" ) ) || exit 1
	    TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${YM}01   -ge ) || error_exit
	    TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${YMPP}01 -lt ) || error_exit
	fi
	echo "YM=${YM} (TMIN=${TMIN}, TMAX=${TMAX})"
	#
	INPUT_DSET_LIST=( $( grads_ctl.pl ${INPUT_CTL} DSET "${TMIN}:${TMAX}" ) )
	INPUT_NC_LIST=()
	for INPUT_DSET in ${INPUT_DSET_LIST[@]} ; do
	    INPUT_NC_TMP=${INPUT_DSET/^/${INPUT_CTL%/*}\//}
	    INPUT_NC=$( readlink -e ${INPUT_NC_TMP} ) \
		|| error_exit "${INPUT_NC_TMP} does not exist."
	    INPUT_NC_LIST+=( ${INPUT_NC} )
	done
	
	cdo -s -b 32 copy ${INPUT_NC_LIST[@]} ${TEMP_DIR}/tmp.nc    || error_exit
	cdo -s -b 32 timmean ${TEMP_DIR}/tmp.nc ${TEMP_DIR}/tmp2.nc || error_exit
	mv ${TEMP_DIR}/tmp2.nc ${OUTPUT_NC} || error_exit
    done  # loop: YM

done  # loop: VAR

(( ${NOTHING} == 1 )) && echo "info: Nothing to do."
echo "$0 normally finished ($(date))."
echo
