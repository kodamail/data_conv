#!/bin/sh
#
# reduce horizontal grid
#
echo "########## $0 start ##########"
set -x
CNFID=$1       # CNFID (e.g. "def")
START_YMD=$2   # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$3   # YYYYMMDD (end+1 day of analysis period)
INPUT_DIR=$4   # input dir
OUTPUT_DIR=$5  # output dir
XYDEF=$6       # output x/y grid in XXXxYYY (e.g. 144x72)
OVERWRITE=$7   # overwrite option (optional)
TARGET_VAR=$8  # variable name (optional)
set +x
echo "##########"

. ./common.sh ${CNFID} || exit 1

create_temp || exit 1
TEMP_DIR=${BASH_COMMON_TEMP_DIR}
trap "finish" 0

if [   "${OVERWRITE}" != ""                                 \
    -a "${OVERWRITE}" != "yes"    -a "${OVERWRITE}" != "no" \
    -a "${OVERWRITE}" != "dry-rm" -a "${OVERWRITE}" != "rm" ] ; then
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
#    if [ -f "${OUTPUT_CTL}" ] ; then
    if [ -f "${OUTPUT_CTL}" -a "${OVERWRITE}" != "rm" -a "${OVERWRITE}" != "dry-rm" ] ; then
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
    XDEF_OUT=$( echo ${XYDEF} | cut -d x -f 1 )
    YDEF_OUT=$( echo ${XYDEF} | cut -d x -f 2 )
    XDEF_OUT_START=$( echo "scale=7; 360.0 / ${XDEF_OUT} / 2" | bc ) || exit 1
    XDEF_OUT_INT=$(   echo "scale=7; 360.0 / ${XDEF_OUT}"     | bc ) || exit 1
    let YDEF_OUT_TMP=YDEF_OUT/2*2
    if [ ${YDEF_OUT} -ne ${YDEF_OUT_TMP} ] ; then # if YDEF is odd  -> [-90:90]
	YDEF_OUT_START="-90.0"
	YDEF_OUT_END="90.0"
	YDEF_OUT_INT=$(   echo "scale=7; 180.0 / (${YDEF_OUT}-1)"     | bc ) || exit 1
    else  # if YDEF is even -> [-8_:8_] (default in roughen)
	YDEF_OUT_START=$( echo "scale=7; -90 + 180 / ${YDEF_OUT} / 2" | bc ) || exit 1
	YDEF_OUT_END=$(   echo "scale=7;  90 - 180 / ${YDEF_OUT} / 2" | bc ) || exit 1
	YDEF_OUT_INT=$(   echo "scale=7; 180.0 / ${YDEF_OUT}"         | bc ) || exit 1
    fi
    let TDEF_FILE=60*60*24/TDEF_INCRE_SEC       # number of time step per file
    let TDEF_SEC_FILE=TDEF_INCRE_SEC*TDEF_FILE  # time in second per file
    #
    #---- generate control file (unified)
    #
    mkdir -p ${OUTPUT_DIR}/${VAR}/log || exit 1
    if [ "${OVERWRITE}" != "rm" -a "${OVERWRITE}" != "dry-rm" ] ; then
	grads_ctl.pl ${INPUT_CTL} > ${OUTPUT_CTL}.tmp1 || exit 1
        #
	sed ${OUTPUT_CTL}.tmp1 \
	    -e "/^CHSUB .*/d"  \
            -e "s/^OPTIONS .*$/OPTIONS TEMPLATE BIG_ENDIAN/i" \
	    -e "s/^UNDEF .*$/UNDEF -99.9e+33/" \
            -e "/^XDEF/,/^YDEF/{" \
            -e "/^\(XDEF\|YDEF\)/!D" \
            -e "}" \
            -e "s/^XDEF.*/XDEF  ${XDEF_OUT}  LINEAR  ${XDEF_OUT_START}  ${XDEF_OUT_INT}/" \
            -e "/YDEF/,/^ZDEF/{" \
            -e "/^\(YDEF\|ZDEF\)/!D" \
            -e "}" \
            -e "s/^YDEF.*/YDEF  ${YDEF_OUT}  LINEAR  ${YDEF_OUT_START}  ${YDEF_OUT_INT}/" \
            -e "s/^VARS .*$/VARS  1/" \
            -e "/^VARS/,/^ENDVARS/{" \
            -e "/^\(VARS\|ENDVARS\|${VAR}\)/!D" \
            -e "}" \
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
	    rm ${OUTPUT_CTL}.tmp ${OUTPUT_CTL}.tmp[12] ${OUTPUT_CTL}.chsub
	else
	    sed ${OUTPUT_CTL}.tmp2 \
		-e "s|^DSET .*$|DSET \^%y4/${VAR}_%y4%m2%d2.grd|" \
		> ${OUTPUT_CTL} || exit 1
	fi
	rm -f ${OUTPUT_CTL}.tmp ${OUTPUT_CTL}.tmp[12] ${OUTPUT_CTL}.chsub
    fi
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
	    SIZE_OUT_EXACT=$( echo 4*${XDEF_OUT}*${YDEF_OUT}*${ZDEF}*${TDEF_FILE} | bc ) || exit 1
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
	#----- combine necessary input file
	#
	echo "YMD=${YMD}"
	if [ "${START_HMS}" != "000000" ] ; then
	    grads_get_data.sh ${VERBOSE_OPT} ${INPUT_CTL} ${VAR} ${TEMP_DIR}/${VAR}_${YMD}.grd.in \
		-ymd "(${YMD}:${YMDPP}]" || exit 1   # one day = [00:01 - 24:00]
	else
	    grads_get_data.sh ${VERBOSE_OPT} ${INPUT_CTL} ${VAR} ${TEMP_DIR}/${VAR}_${YMD}.grd.in \
		-ymd "[${YMD}:${YMDPP})" || exit 1   # one day = [00:00 - 23:59]
	fi
	#
	#----- roughen
	#
        # assuming globally uniform grid
	#
	NOTHING=0
	cd ${TEMP_DIR}
	# for 2013/04/18 or later NICAM
	cat > roughen.cnf <<EOF
&ROUGHEN_PARAM
    indir         = './',               ! input directory name
    insuffix      = '_${YMD}.grd.in',   ! suffix of original data
    input_netcdf  = .false.,
    imax_in       = ${XDEF},            ! grid number for x-axis (original data)
    jmax_in       = ${YDEF},            ! grid number for y-axis (original data)

    outdir        = '.',                ! output directory name
    outsuffix     = '_${YMD}.grd',      ! suffix of output data
    output_netcdf = .false.,
    imax_out      = ${XDEF_OUT},        ! grid number for x-axis (output data)
    jmax_out      = ${YDEF_OUT},        ! grid number for y-axis (output data)

    kmax          = ${ZDEF},            ! vertical grid number
    tmax          = ${TDEF_FILE},       ! time
    varmax        = 1,                  ! variable number
    varname       = '${VAR}',
    undef         = -99.9e+33,
    latmin_out    = ${YDEF_OUT_START},
    latmax_out    = ${YDEF_OUT_END},
/
EOF
        ${BIN_ROUGHEN} || exit 1
	#
	mv ${VAR}_${YMD}.grd ../${OUTPUT_DIR}/${VAR}/${YEAR}/ || exit 1
	mv roughen.cnf       ../${OUTPUT_DIR}/${VAR}/log/roughen_${YMD}.cnf
	rm ${VAR}_${YMD}.grd.in
	cd - > /dev/null || exit 1

    done  # date loop

done  # variable loop

[ ${NOTHING} -eq 1 ] && echo "info: Nothing to do."
echo "$0 normally finished."
echo
