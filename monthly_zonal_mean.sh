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

. ./common.sh ${CNFID} || exit 1

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
    #
    #----- check existence of output data
    #
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
    YM_STARTMM=$(     date -u --date "${START_YMD} 1 second ago" +%Y%m ) || error_exit
    YM_END=$( date -u --date "${ENDPP_YMD} 1 month ago"  +%Y%m ) || error_exit
    if [[ -f "${OUTPUT_CTL}" && "${OVERWRITE}" != "rm" && "${OVERWRITE}" != "dry-rm" ]] ; then
        YM_TMP=$(     date -u --date "${YM_STARTMM}01 1 month" +%Y%m ) || error_exit
        FLAG=( $( grads_exist_data.sh ${OUTPUT_CTL} -ymd "[${YM_TMP}15:${YM_END}15]" ) ) || error_exit
        if [[ "${FLAG[0]}" = "ok" ]] ; then
            echo "info: Output data already exist."
            continue
        fi
    fi
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
    TDEF_START=$(     grads_ctl.pl ${INPUT_CTL} TDEF 1 ) || error_exit
    #
    START_HMS=$( date -u --date "${TDEF_START}" +%H%M%S )
    TMP_H=${START_HMS:0:2}
    TMP_M=${START_HMS:2:2}
    let TMP_MN=TMP_H*60+TMP_M
    #
    #----- check existence of input data
    #
    if [[ "${START_HMS}" != "000000" ]] ; then
	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD:0:6}01]" ) ) || error_exit
    else
	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "[${START_YMD}:${ENDPP_YMD:0:6}01)" ) ) || error_exit
    fi
    if [[ "${FLAG[0]}" != "ok" ]] ; then
        echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})."
        continue
    fi
    #
    #---- generate control file (unified)
    #
    mkdir -p ${OUTPUT_DIR}/${VAR}/log
    #if [ "${OVERWRITE}" != "rm" -a "${OVERWRITE}" != "dry-rm" ] ; then
    if [[ ! "${OVERWRITE}" =~ ^(dry-rm|rm)$ ]] ; then
	#grads_ctl.pl ${INPUT_CTL} > ${OUTPUT_CTL}.tmp1 || exit 1

	grads_ctl.pl ${INPUT_CTL} \
	    | sed -e "s|^DSET .*|DSET ^%y4/${VAR}_%y4%m2.grd|" \
	    > ${OUTPUT_CTL}.tmp1 || error_exit	
        #
	sed ${OUTPUT_CTL}.tmp1 \
            -e "/^XDEF/,/^YDEF/{" \
            -e "/^\(XDEF\|YDEF\)/!D" \
            -e "}" \
            -e "s/^XDEF.*/XDEF  1  LEVELS  0.0/" \
            > ${OUTPUT_CTL} || error_exit
	rm ${OUTPUT_CTL}.tmp1
    fi
    #
    #========================================#
    #  month loop (for each file)
    #========================================#
    YM=${YM_STARTMM}
    #while [ ${YM} -lt ${YM_END} ] ; do
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
        #   2004/ms_tem_20040601.grd  (center of the date if incre > 1dy)
        #
        mkdir -p ${OUTPUT_DIR}/${VAR}/${YEAR} || error_exit
        #
        # output file exist?
        for(( e=1; ${e}<=${EDEF}; e=${e}+1 )) ; do
            STR_ENS=""
            if (( ${EDEF} > 1 )) ; then
                STR_ENS=$( printf "%03d" ${e} ) || error_exit
                STR_ENS="_bin${STR_ENS}"
            fi
            #
            OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YEAR}${MONTH}${STR_ENS}.grd
            #
            if [[ -f ${OUTPUT_DATA} ]] ; then
                SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' ) || error_exit
                SIZE_OUT_EXACT=$( echo "4*${YDEF}*${ZDEF}" | bc ) || error_exit
                if [[ ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} && "${OVERWRITE}" != "yes" \
                    && "${OVERWRITE}" != "dry-rm" && "${OVERWRITE}" != "rm" ]] ; then
                    continue 2
                fi
                echo "Removing ${OUTPUT_DATA}."
                echo ""
                [[ "${OVERWRITE}" = "dry-rm" ]] && continue 1
                rm -f ${OUTPUT_DATA}
            fi
        done
        #[ "${OVERWRITE}" = "rm" -o "${OVERWRITE}" = "dry-rm" ] && continue 1
	[[ "${OVERWRITE}" =~ ^(dry-rm|rm)$ ]] && continue
        #
        # average
        #
        NOTHING=0
        echo "YM=${YM}"
        #
        cd ${TEMP_DIR}
        for(( e=1; ${e}<=${EDEF}; e=${e}+1 )) ; do
            STR_ENS=""
            TEMPLATE_ENS=""
            if (( ${EDEF} > 1 )) ; then
                STR_ENS=$( printf "%03d" ${e} ) || error_exit
                STR_ENS="_bin${STR_ENS}"
                TEMPLATE_ENS="_bin%e"
            fi
            OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YEAR}${MONTH}${STR_ENS}.grd
	    #
            #----- zonal mean
	    #	
	    YMD_TMP="(${YM}01:${YMPP}01]"
	    if [[ "${START_HMS}" != "000000" ]] ; then
		YMD_TMP="[${YM}01:${YMPP}01)"
		error_exit "It is not fully checked. Please check!"
	    fi
	    if (( ${VERBOSE} >= 1 )) ; then
		grads_zonal_mean.sh ${VERBOSE_OPT} ../${INPUT_CTL} ${VAR} ${VAR}_${YM}.grd -ymd "${YMD_TMP}" || error_exit
	    else
		grads_zonal_mean.sh ${VERBOSE_OPT} ../${INPUT_CTL} ${VAR} ${VAR}_${YM}.grd -ymd "${YMD_TMP}" > temp.log \
		    || { cat temp.log ; error_exit ; }
	    fi
	    #
	    mv ${VAR}_${YM}.grd ../${OUTPUT_DATA} || error_exit

        done
        cd - > /dev/null || exit 1

    done  # year/month loop

done  # variable loop

(( ${NOTHING} == 1 )) && echo "info: Nothing to do."
echo "$0 normally finished."
echo
