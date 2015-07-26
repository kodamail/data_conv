#!/bin/sh
#
. ./common.sh     || exit 1

echo "########## $0 start ##########"
set -x
START_DATE=$1    # date (YYYYMMDD)
ENDPP_DATE=$2    # date (YYYYMMDD)
INPUT_DIR=$3
OUTPUT_DIR=$4
OVERWRITE=$5   # optional
TARGET_VAR=$6  # optional
set +x
echo "##########"

create_temp
TEMP_DIR=${BASH_COMMON_TEMP_DIR}
trap "finish" 0

if [   "${OVERWRITE}" != ""       \
    -a "${OVERWRITE}" != "yes"    \
    -a "${OVERWRITE}" != "no"     \
    -a "${OVERWRITE}" != "dry-rm" \
    -a "${OVERWRITE}" != "rm"  ] ; then
    echo "error: OVERWRITE = ${OVERWRITE} is not supported yet."
    exit 1
fi


if [ "${TARGET_VAR}" = "" ] ; then
    VAR_LIST=( $( ls ${INPUT_DIR}/ ) ) || exit 1
else
    VAR_LIST=( ${TARGET_VAR} )
fi

NOTHING=1
#=====================================#
#      var loop                       #
#=====================================#
for VAR in ${VAR_LIST[@]} ; do
    #
    # check output dir
    #
    if [ -f "${OUTPUT_DIR}/${VAR}/_locked" ] ; then
	echo "info: ${OUTPUT_DIR} is locked."
	continue
    fi
    #
    # check output data
    #
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
    if [ -f ${OUTPUT_CTL} ] ; then
	FLAG=( $( exist_data.sh \
	    ${OUTPUT_CTL} \
	    $( time_2_grads ${START_DATE} ) \
	    $( time_2_grads ${ENDPP_DATE} ) \
	    "PP" ) ) || exit 1
	if [ "${FLAG[0]}" = "ok" ] ; then
	    echo "info: Output data already exist."
	    continue
	fi
    fi
    #
    # check input data
    #
    INPUT_CTL=${INPUT_DIR}/${VAR}/${VAR}.ctl
    if [ ! -f ${INPUT_CTL} ] ; then
	echo "warning: ${INPUT_CTL} does not exist."
	continue
    fi
    FLAG=( $( exist_data.sh \
	${INPUT_CTL} \
	$( time_2_grads ${START_DATE} ) \
	$( time_2_grads ${ENDPP_DATE} ) \
	"PP" ) ) || exit 1
    if [ "${FLAG[0]}" != "ok" ] ; then
	echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})."
	continue
    fi
    EXT=grd
    TMP=$( echo "${FLAG[1]}" | grep ".nc$" )
    if [ "${TMP}" != "" ] ; then
	EXT=nc
	INPUT_NC_1=${FLAG[1]}
    fi
    #
    # get number of grid
    #
    DIMS=( $( ${BIN_GRADS_CTL} ${INPUT_CTL} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]} ; TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    TDEF_START=$(     ${BIN_GRADS_CTL} ${INPUT_CTL} TDEF 1 ) || exit 1
    TDEF_INCRE_SEC=$( ${BIN_GRADS_CTL} ${INPUT_CTL} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
    TDEF_INCRE_MN=$(  ${BIN_GRADS_CTL} ${INPUT_CTL} TDEF INC --unit MN  | sed -e "s/MN//"  ) || exit 1
    #
    OUTPUT_TDEF_ONEFILE=$( echo "60 * 60 * 24 / ${TDEF_INCRE_SEC}" | bc ) || exit 1   # per one file
    [ ! -d ${OUTPUT_DIR}/${VAR}     ] && mkdir -p ${OUTPUT_DIR}/${VAR}
    [ ! -d ${OUTPUT_DIR}/${VAR}/log ] && mkdir -p ${OUTPUT_DIR}/${VAR}/log
    #
    # generate control file (unified)
    #
    if [ "${EXT}" = "nc" ] ; then
	${BIN_NC2CTL} ${INPUT_NC_1} ${OUTPUT_CTL}.tmp1 || exit 1
    else
	cp ${INPUT_CTL} ${OUTPUT_CTL}.tmp1
    fi
    #
    rm -f ${OUTPUT_CTL}.chsub
    for(( d=1; ${d}<=${TDEF}; d=${d}+${OUTPUT_TDEF_ONEFILE} )) ; do
	CHSUB_MIN=${d}
	CHSUB_MAX=$( echo "${d} + ${OUTPUT_TDEF_ONEFILE} - 1" | bc )
	if [ ${d} -eq 1 ] ; then
	    DATE_GRADS=${TDEF_START}
	else
	    for(( dd=1; ${dd}<=${OUTPUT_TDEF_ONEFILE}; dd=${dd}+1 )) ; do
		DATE_GRADS=$( date -u --date "${DATE_GRADS} ${TDEF_INCRE_SEC} seconds" +%H:%Mz%d%b%Y )
	    done
	fi
	DATE=$( date -u --date "${DATE_GRADS}" +%Y%m%d ) || exit 1
	YEAR=$( date -u --date "${DATE_GRADS}" +%Y     ) || exit 1
#	echo "CHSUB  ${CHSUB_MIN}  ${CHSUB_MAX}  ${DATE}" >> ${OUTPUT_CTL}.chsub
	echo "CHSUB  ${CHSUB_MIN}  ${CHSUB_MAX}  ${YEAR}/${DATE}" >> ${OUTPUT_CTL}.chsub
    done
#        -e "s/^DSET .*$/DSET \^${VAR}_%ch.grd/" \
    sed ${OUTPUT_CTL}.tmp1 \
        -e "s|^DSET .*$|DSET \^%ch/${VAR}.grd|" \
	-e "/^CHSUB .*/d"  \
	-e "s/TEMPLATE//ig" \
        -e "s/^OPTIONS /OPTIONS TEMPLATE /i" \
	-e "s/^UNDEF .*$/UNDEF -0.99900E+35/i"  \
        -e "/^XDEF/,/^YDEF/{" \
        -e "/^\(XDEF\|YDEF\)/!D" \
        -e "}" \
        -e "s/^XDEF.*/XDEF  1  LEVELS  0.0/" \
        -e "s/^TDEF .*$/TDEF    ${TDEF}  LINEAR  ${TDEF_START}  ${TDEF_INCRE_MN}mn/" \
	> ${OUTPUT_CTL}.tmp || exit 1
    sed -e "/^DSET/q" ${OUTPUT_CTL}.tmp   >  ${OUTPUT_CTL} || exit 1
    cat ${OUTPUT_CTL}.chsub               >> ${OUTPUT_CTL} || exit 1
    sed -e "0,/^DSET/d" ${OUTPUT_CTL}.tmp >> ${OUTPUT_CTL} || exit 1
    rm ${OUTPUT_CTL}.tmp ${OUTPUT_CTL}.tmp1 ${OUTPUT_CTL}.chsub

    #=====================================#
    #      date loop (for each file)      #
    #=====================================#
    for(( d=1; ${d}<=${TDEF}; d=${d}+${OUTPUT_TDEF_ONEFILE} )) ; do

	if [ ${d} -eq 1 ] ; then
	    DATE_GRADS=${TDEF_START}
	else
	    for(( dd=1; ${dd}<=${OUTPUT_TDEF_ONEFILE}; dd=${dd}+1 )) ; do
		DATE_GRADS=$( date -u --date "${DATE_GRADS} ${TDEF_INCRE_SEC} seconds" +%H:%Mz%d%b%Y ) || exit 1
	    done
	fi
	DATE=$(     date -u --date "${DATE_GRADS}" +%Y%m%d ) || exit 1
	DATE_SEC=$( date -u --date "${DATE_GRADS}" +%s )     || exit 1
	TMP_SEC_MIN=$(  date -u --date "00:00z${START_DATE}" +%s ) || exit 1
	TMP_SEC_MAX=$(  date -u --date "00:00z${ENDPP_DATE}" +%s ) || exit 1
	if [ ${TMP_SEC_MIN} -gt ${DATE_SEC} -o ${TMP_SEC_MAX} -lt ${DATE_SEC} ] ; then
	    continue
	fi
	#echo "date=${DATE}"
        #
        #----- set date for ${DATE} -----#
        #
	YEAR=${DATE:0:4}
	MONTH=${DATE:4:2}
	DAY=${DATE:6:2}
	#
	TMIN=${d}
	TMAX=$( echo "${d}+${OUTPUT_TDEF_ONEFILE}-1" | bc ) || exit 1
	#echo "${TMIN} ${TMAX}"
	#
        #----- output data -----#
	#
        #
        # File name convention
        #   ms_tem_20040601.grd  (center of the date if incre > 1dy)
	#
	#OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_${YEAR}${MONTH}${DAY}.grd
	OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${DATE}/${VAR}.grd
	mkdir -p ${OUTPUT_DIR}/${VAR}/${YEAR}/${DATE}
	#
        # output file exist?
	if [ -f ${OUTPUT_DATA} ] ; then
	    SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' ) || exit 1
	    SIZE_OUT_EXACT=$( echo 4*1*${YDEF}*${ZDEF}*${OUTPUT_TDEF_ONEFILE} | bc ) || exit 1
	    #echo ${SIZE_OUT} ${SIZE_OUT_EXACT}
	    if [   ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} \
		-a "${OVERWRITE}" != "yes" \
		-a "${OVERWRITE}" != "dry-rm" \
		-a "${OVERWRITE}" != "rm" ] ; then
		continue 1
	    fi
	    echo "Removing ${OUTPUT_DATA}."
	    echo ""
	    [ "${OVERWRITE}" = "dry-rm" ] && continue 1
	    rm -f ${OUTPUT_DATA}
	fi
	[ "${OVERWRITE}" = "rm" -o "${OVERWRITE}" = "dry-rm" ] && exit
	
	NOTHING=0

	#
	#----- combine necessary input file -----#
	#
	get_data ${INPUT_CTL} ${VAR} ${TMIN} ${TMAX} \
	    ${TEMP_DIR}/${VAR}_${DATE}.grd.in || exit 1

	#
        # zonal mean
	#
	cd ${TEMP_DIR}
	NUM=$( echo ${YDEF}*${ZDEF}*${OUTPUT_TDEF_ONEFILE} | bc ) || exit 1
	${BIN_ZONAL_MEAN} dummy \
            ${VAR}_${DATE}.grd.in ${VAR}_${DATE}.grd \
            ${XDEF} ${NUM} -0.99900e+35 || exit 1
	mv ${VAR}_${DATE}.grd ../${OUTPUT_DATA}
	cd - > /dev/null
    done

done

[ ${NOTHING} -eq 1 ] && echo "info: Nothing to do."

echo "$0 normally finished."
