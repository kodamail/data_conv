#!/bin/sh
#
# zonal mean
#
. ./common.sh || exit 1

echo "########## $0 start ##########"
set -x
START_YMD=$1   # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$2   # YYYYMMDD (end+1 day of analysis period)
INPUT_DIR=$3   # input dir
OUTPUT_DIR=$4  # output dir
OVERWRITE=$5   # overwrite option (optional)
TARGET_VAR=$6  # variable name (optional)
set +x
echo "##########"

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
    if [ -f "${OUTPUT_CTL}" ] ; then
        FLAG=( $( grads_exist_data.sh ${OUTPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
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
    TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_CTL} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
    TDEF_INCRE_MN=$(  grads_ctl.pl ${INPUT_CTL} TDEF INC --unit MN  | sed -e "s/MN//"  ) || exit 1
    #
    let TDEF_FILE=60*60*24/TDEF_INCRE_SEC       # number of time step per file
    let TDEF_SEC_FILE=TDEF_INCRE_SEC*TDEF_FILE  # time in second per file
    #                                                                                                 
    START_HMS=$( date -u --date "${TDEF_START}" +%H%M%S )
    TMP_H=${START_HMS:0:2}
    TMP_M=${START_HMS:2:2}
    let TMP_MN=TMP_H*60+TMP_M
    #
    #----- check existence of input data
    #
    if [ "${START_HMS}" != "000000" ] ; then
	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
    else
	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "[${START_YMD}:${ENDPP_YMD})" ) ) || exit 1
    fi
    if [ "${FLAG[0]}" != "ok" ] ; then
        echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})."
        continue
    fi
    #
    #---- generate control file (unified)
    #
    mkdir -p ${OUTPUT_DIR}/${VAR}/log
    grads_ctl.pl ${INPUT_CTL} > ${OUTPUT_CTL}.tmp1 || exit 1
    #
    sed ${OUTPUT_CTL}.tmp1 \
	-e "/^CHSUB .*/d"  \
	-e "s/TEMPLATE//ig" \
        -e "s/^OPTIONS .*$/OPTIONS TEMPLATE BIG_ENDIAN/i" \
	-e "s/^UNDEF .*$/UNDEF -0.99900E+35/i"  \
        -e "/^XDEF/,/^YDEF/{" \
        -e "/^\(XDEF\|YDEF\)/!D" \
        -e "}" \
        -e "s/^XDEF.*/XDEF  1  LEVELS  0.0/" \
	> ${OUTPUT_CTL}.tmp2 || exit 1
    if [ "${START_HMS}" != "000000" ] ; then
	rm -f ${OUTPUT_CTL}.chsub
	DATE=$( date -u --date "${TDEF_START}" +%Y%m%d\ %H:%M:%S ) || exit 1  # YYYYMMDD HH:MM:SS
	echo "CHSUB  1  ${TDEF_FILE}  ${DATE:0:4}/${VAR}_${DATE:0:8}" >> ${OUTPUT_CTL}.chsub
	for(( d=1+${TDEF_FILE}; ${d}<=${TDEF}; d=${d}+${TDEF_FILE} )) ; do
            let CHSUB_MAX=d+TDEF_FILE-1
            DATE=$( date -u --date "${DATE} ${TDEF_SEC_FILE} seconds" +%Y%m%d\ %H:%M:%S ) || exit 1
            echo "CHSUB  ${d}  ${CHSUB_MAX}  ${DATE:0:4}/${VAR}_${DATE:0:8}" >> ${OUTPUT_CTL}.chsub
	done
	sed ${OUTPUT_CTL}.tmp2 \
            -e "s|^DSET .*$|DSET \^%ch.grd|" \
            -e "s/^TDEF .*$/TDEF    ${TDEF}  LINEAR  ${TDEF_START}  ${TDEF_INCRE_MN}mn/" \
	    > ${OUTPUT_CTL}.tmp || exit 1
	sed -e "/^DSET/q" ${OUTPUT_CTL}.tmp    > ${OUTPUT_CTL} || exit 1
	cat ${OUTPUT_CTL}.chsub               >> ${OUTPUT_CTL} || exit 1
	sed -e "0,/^DSET/d" ${OUTPUT_CTL}.tmp >> ${OUTPUT_CTL} || exit 1
    else
        sed ${OUTPUT_CTL}.tmp2 \
            -e "s|^DSET .*$|DSET \^%y4/${VAR}_%y4%m2%d2.grd|" \
            > ${OUTPUT_CTL} || exit 1
    fi
    rm -f ${OUTPUT_CTL}.tmp ${OUTPUT_CTL}.tmp[12] ${OUTPUT_CTL}.chsub
    #
    #========================================#
    #  date loop (for each file)
    #========================================#
    for(( d=1; ${d}<=${TDEF}; d=${d}+${TDEF_FILE} )) ; do
        #
        #----- set/proceed date -----#
        #
        if [ ${d} -eq 1 ] ; then
            DATE=$( date -u --date "${TDEF_START}" +%Y%m%d\ %H:%M:%S ) || exit 1
        else
            DATE=$( date -u --date "${DATE} ${TDEF_SEC_FILE} seconds" +%Y%m%d\ %H:%M:%S ) || exit 1
        fi
        YMD=${DATE:0:8}
        #
        [ ${YMD} -lt ${START_YMD} ] && continue
        [ ${YMD} -ge ${ENDPP_YMD} ] && break
        #
        YMDPP=$( date -u --date "${YMD} 1 day" +%Y%m%d ) || exit 1
        YEAR=${DATE:0:4} ; MONTH=${DATE:4:2} ; DAY=${DATE:6:2}
        #
        #----- output data
        #
        # File name convention
        #   2004/ms_tem_20040601.grd  (center of the date if incre > 1dy)
        #
        OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YMD}.grd
        mkdir -p ${OUTPUT_DIR}/${VAR}/${YEAR} || exit 1
        #
        #----- output file exist?
        #
        if [ -f "${OUTPUT_DATA}" ] ; then
            SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' ) || exit 1
            SIZE_OUT_EXACT=$( echo 4*1*${YDEF}*${ZDEF}*${TDEF_FILE} | bc ) || exit 1
            if [   ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} -a "${OVERWRITE}" != "yes" \
                -a "${OVERWRITE}" != "dry-rm" -a "${OVERWRITE}" != "rm" ] ; then
                continue 1
            fi
            echo "Removing ${OUTPUT_DATA}."
            echo ""
            [ "${OVERWRITE}" = "dry-rm" ] && continue 1
            rm -f ${OUTPUT_DATA}
        fi
        [ "${OVERWRITE}" = "rm" -o "${OVERWRITE}" = "dry-rm" ] && exit
	#
        #----- zonal mean
	#	
        echo "YMD=${YMD}"
	NOTHING=0
	cd ${TEMP_DIR}
	YMD_TMP="(${YMD}:${YMDPP}]"
        if [ "${START_HMS}" != "000000" ] ; then
	    YMD_TMP="[${YMD}:${YMDPP})"
	    echo "It is not fully checked. Please check!"
	    exit 1
	fi
	if [ ${VERBOSE} -ge 1 ] ; then
	    grads_zonal_mean.sh ${VERBOSE_OPT} ../${INPUT_CTL} ${VAR} ${VAR}_${YMD}.grd -ymd "${YMD_TMP}" || exit 1
	else
	    grads_zonal_mean.sh ${VERBOSE_OPT} ../${INPUT_CTL} ${VAR} ${VAR}_${YMD}.grd -ymd "${YMD_TMP}" > temp.log \
		|| { cat temp.log ; echo "error" ; exit 1 ; }
	fi
	#
	mv ${VAR}_${YMD}.grd ../${OUTPUT_DATA} || exit 1
	cd - > /dev/null || exit 1

    done  # data loop

done  # variable loop

[ ${NOTHING} -eq 1 ] && echo "info: Nothing to do."
echo "$0 normally finished."
echo
