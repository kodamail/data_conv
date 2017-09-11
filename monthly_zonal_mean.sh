#!/bin/sh
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

create_temp || exit 1
TEMP_DIR=${BASH_COMMON_TEMP_DIR}
trap "finish" 0

if [   "${OVERWRITE}" != ""                                  \
    -a "${OVERWRITE}" != "yes"    -a "${OVERWRITE}" != "no"  \
    -a "${OVERWRITE}" != "dry-rm" -a "${OVERWRITE}" != "rm"  ] ; then
    echo "error: OVERWRITE = ${OVERWRITE} is not supported yet." >&2
    exit 1
fi

if [ "${TARGET_VAR}" = "" ] ; then
    VAR_LIST=( $( ls ${INPUT_DIR}/ ) ) || exit 1
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
    if [ -f "${OUTPUT_DIR}/${VAR}/_locked" ] ; then
        echo "info: ${OUTPUT_DIR} is locked."
        continue
    fi
    #
    #----- check existence of output data
    #
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
    YM_STARTMM=$(     date -u --date "${START_YMD} 1 second ago" +%Y%m ) || exit 1
    YM_END=$( date -u --date "${ENDPP_YMD} 1 month ago"  +%Y%m ) || exit 1
#    if [ -f "${OUTPUT_CTL}" ] ; then
    if [ -f "${OUTPUT_CTL}" -a "${OVERWRITE}" != "rm" -a "${OVERWRITE}" != "dry-rm" ] ; then
        YM_TMP=$(     date -u --date "${YM_STARTMM}01 1 month" +%Y%m ) || exit 1
        FLAG=( $( grads_exist_data.sh ${OUTPUT_CTL} -ymd "[${YM_TMP}15:${YM_END}15]" ) ) || exit 1
        if [ "${FLAG[0]}" = "ok" ] ; then
            echo "info: Output data already exist."
            continue
        fi
    fi
    #
    #----- get number of grids for input/output
    #
    INPUT_CTL=${INPUT_DIR}/${VAR}/${VAR}.ctl
    if [ ! -f "${INPUT_CTL}" ] ; then
        echo "warning: ${INPUT_CTL} does not exist."
        continue
    fi
    DIMS=( $( grads_ctl.pl ${INPUT_CTL} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}
    TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    TDEF_START=$(     grads_ctl.pl ${INPUT_CTL} TDEF 1 ) || exit 1
    #                                                                                                 
    START_HMS=$( date -u --date "${TDEF_START}" +%H%M%S )
    TMP_H=${START_HMS:0:2}
    TMP_M=${START_HMS:2:2}
    let TMP_MN=TMP_H*60+TMP_M
    #
    #----- check existence of input data
    #
    if [ "${START_HMS}" != "000000" ] ; then
	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD:0:6}01]" ) ) || exit 1
    else
	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "[${START_YMD}:${ENDPP_YMD:0:6}01)" ) ) || exit 1
    fi
    if [ "${FLAG[0]}" != "ok" ] ; then
        echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})."
        continue
    fi
    #
    #---- generate control file (unified)
    #
    mkdir -p ${OUTPUT_DIR}/${VAR}/log
    if [ "${OVERWRITE}" != "rm" -a "${OVERWRITE}" != "dry-rm" ] ; then
	grads_ctl.pl ${INPUT_CTL} > ${OUTPUT_CTL}.tmp1 || exit 1
        #
	sed ${OUTPUT_CTL}.tmp1 \
            -e "/^XDEF/,/^YDEF/{" \
            -e "/^\(XDEF\|YDEF\)/!D" \
            -e "}" \
            -e "s/^XDEF.*/XDEF  1  LEVELS  0.0/" \
            > ${OUTPUT_CTL} || exit 1
	rm ${OUTPUT_CTL}.tmp1
    fi
    #
    #========================================#
    #  month loop (for each file)
    #========================================#
    YM=${YM_STARTMM}
    while [ ${YM} -lt ${YM_END} ] ; do
        #
        #----- set/proceed date -----#
        #
        YM=$(   date -u --date "${YM}01 1 month" +%Y%m ) || exit 1
        YMPP=$( date -u --date "${YM}01 1 month" +%Y%m ) || exit 1
        YEAR=${YM:0:4} ; MONTH=${YM:4:2}
        #
        #----- output data
        #
        # File name convention
        #   2004/ms_tem_20040601.grd  (center of the date if incre > 1dy)
        #
        mkdir -p ${OUTPUT_DIR}/${VAR}/${YEAR} || exit 1
        #
        # output file exist?
        for(( e=1; ${e}<=${EDEF}; e=${e}+1 )) ; do
            STR_ENS=""
            if [ ${EDEF} -gt 1 ] ; then
                STR_ENS=$( printf "%03d" ${e} ) || exit 1
                STR_ENS="_bin${STR_ENS}"
            fi
            #
            OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YEAR}${MONTH}${STR_ENS}.grd
            #
            if [ -f ${OUTPUT_DATA} ] ; then
                SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' ) || exit 1
                SIZE_OUT_EXACT=$( echo "4*${YDEF}*${ZDEF}" | bc ) || exit 1
                if [ ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} -a "${OVERWRITE}" != "yes" \
                    -a "${OVERWRITE}" != "dry-rm" -a "${OVERWRITE}" != "rm" ] ; then
                    continue 2
                fi
                echo "Removing ${OUTPUT_DATA}."
                echo ""
                [ "${OVERWRITE}" = "dry-rm" ] && continue 1
                rm -f ${OUTPUT_DATA}
            fi
        done
        [ "${OVERWRITE}" = "rm" -o "${OVERWRITE}" = "dry-rm" ] && continue 1
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
            if [ ${EDEF} -gt 1 ] ; then
                STR_ENS=$( printf "%03d" ${e} ) || exit 1
                STR_ENS="_bin${STR_ENS}"
                TEMPLATE_ENS="_bin%e"
            fi
            OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YEAR}${MONTH}${STR_ENS}.grd
	    #
            #----- zonal mean
	    #	
	    YMD_TMP="(${YM}01:${YMPP}01]"
	    if [ "${START_HMS}" != "000000" ] ; then
		YMD_TMP="[${YM}01:${YMPP}01)"
		echo "It is not fully checked. Please check!"
		exit 1
	    fi
	    if [ ${VERBOSE} -ge 1 ] ; then
		grads_zonal_mean.sh ${VERBOSE_OPT} ../${INPUT_CTL} ${VAR} ${VAR}_${YM}.grd -ymd "${YMD_TMP}" || exit 1
	    else
		grads_zonal_mean.sh ${VERBOSE_OPT} ../${INPUT_CTL} ${VAR} ${VAR}_${YM}.grd -ymd "${YMD_TMP}" > temp.log \
		    || { cat temp.log ; echo "error" ; exit 1 ; }
	    fi
	    #
	    mv ${VAR}_${YM}.grd ../${OUTPUT_DATA} || exit 1

        done
        cd - > /dev/null || exit 1

    done  # year/month loop

done  # variable loop

[ ${NOTHING} -eq 1 ] && echo "info: Nothing to do."
echo "$0 normally finished."
echo
