#!/bin/sh
#
# convert from z to p coordinate
#
. ./common.sh || exit 1

echo "########## $0 start ##########"
set -x
START_YMD=$1   # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$2   # YYYYMMDD (end+1 day of analysis period)
INPUT_DIR=$3   # input dir
OUTPUT_DIR=$4  # output dir
PDEF_LEVELS=$5 # pressure levels separated by comma
OVERWRITE=$6   # overwrite option (optional)
TARGET_VAR=$7  # variable name (optional)
set +x
echo "##########"

create_temp || exit 1
TEMP_DIR=${BASH_COMMON_TEMP_DIR}
trap "finish" 0

if [   "${OVERWRITE}" != ""                                  \
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
    VAR_PRES=m${VAR:1:1}_pres
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
    #----- check existence of input data
    #
    INPUT_CTL=${INPUT_DIR}/${VAR}/${VAR}.ctl
    INPUT_PRES_CTL=${INPUT_DIR}/${VAR_PRES}/${VAR_PRES}.ctl
    for CTL in ${INPUT_PRES_CTL} ${INPUT_CTL} ; do
	if [ ! -f "${CTL}" ] ; then
	    echo "warning: ${CTL} does not exist."
	    continue 2
	fi
	FLAG=( $( grads_exist_data.sh ${CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
	if [ "${FLAG[0]}" != "ok" ] ; then
	    echo "warning: All or part of data does not exist (CTL=${CTL})."
	    continue 2
	fi
    done
    #
    #----- get number of grids for input/output
    #
    DIMS=( $( grads_ctl.pl ${INPUT_CTL} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}
    TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    TDEF_START=$(     grads_ctl.pl ${INPUT_CTL} TDEF 1 ) || exit 1
    TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_CTL} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
    TDEF_INCRE_MN=$(  grads_ctl.pl ${INPUT_CTL} TDEF INC --unit MN  | sed -e "s/MN//"  ) || exit 1
    #
    PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1
    let TDEF_FILE=60*60*24/TDEF_INCRE_SEC       # number of time step per file
    let TDEF_SEC_FILE=TDEF_INCRE_SEC*TDEF_FILE  # time in second per file
    #
    #---- generate control file (unified)
    #
    mkdir -p ${OUTPUT_DIR}/${VAR}/log || exit 1
    grads_ctl.pl ${INPUT_CTL} > ${OUTPUT_CTL}.tmp1 || exit 1
    #
    rm -f ${OUTPUT_CTL}.chsub
    DATE=$( date -u --date "${TDEF_START}" +%Y%m%d\ %H:%M:%S ) || exit 1  # YYYYMMDD HH:MM:SS
    echo "CHSUB  1  ${TDEF_FILE}  ${DATE:0:4}/${VAR}_${DATE:0:8}" >> ${OUTPUT_CTL}.chsub
    for(( d=1+${TDEF_FILE}; ${d}<=${TDEF}; d=${d}+${TDEF_FILE} )) ; do
        let CHSUB_MAX=d+TDEF_FILE-1
        DATE=$( date -u --date "${DATE} ${TDEF_SEC_FILE} seconds" +%Y%m%d\ %H:%M:%S ) || exit 1
        echo "CHSUB  ${d}  ${CHSUB_MAX}  ${DATE:0:4}/${VAR}_${DATE:0:8}" >> ${OUTPUT_CTL}.chsub
    done
    PDEF_LIST=$( echo ${PDEF_LEVELS} | sed -e "s/,/ /"g ) || exit 1
    sed ${OUTPUT_CTL}.tmp1 \
        -e "s|^DSET .*$|DSET \^%ch.grd|" \
	-e "/^CHSUB .*/d"  \
	-e "s/TEMPLATE//ig" \
        -e "s/^OPTIONS .*$/OPTIONS TEMPLATE BIG_ENDIAN/i" \
	-e "s/^UNDEF .*$/UNDEF -0.99900E+35/i"  \
	-e "/^ZDEF/,/^TDEF/{" \
	-e "/^\(ZDEF\|TDEF\)/!D" \
	-e "}" \
	-e "s/^ZDEF .*/ZDEF  ${PDEF}  LEVELS  ${PDEF_LIST}/" \
        -e "s/^TDEF .*$/TDEF    ${TDEF}  LINEAR  ${TDEF_START}  ${TDEF_INCRE_MN}mn/" \
	-e "s/^\(${VAR} *\)${ZDEF}/\1${PDEF}/" \
	> ${OUTPUT_CTL}.tmp || exit 1
    sed -e "/^DSET/q" ${OUTPUT_CTL}.tmp    > ${OUTPUT_CTL}  || exit 1
    cat ${OUTPUT_CTL}.chsub               >> ${OUTPUT_CTL} || exit 1
    sed -e "0,/^DSET/d" ${OUTPUT_CTL}.tmp >> ${OUTPUT_CTL} || exit 1
    rm ${OUTPUT_CTL}.tmp ${OUTPUT_CTL}.tmp1 ${OUTPUT_CTL}.chsub
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
	    SIZE_OUT_EXACT=$( echo 4*${XDEF}*${YDEF}*${PDEF}*${TDEF_FILE} | bc ) || exit 1
	    if [   ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} -a "${OVERWRITE}" != "yes" \
		-a "${OVERWRITE}" != "dry-rm" -a "${OVERWRITE}" != "rm" ] ; then
		continue 1
	    fi
	    echo "Removing ${OUTPUT_DATA}."
	    echo ""
	    [ "${OVERWRITE}" = "dry-rm" ] && continue 1
	    rm -f ${OUTPUT_DATA}
	fi
	[ "${OVERWRITE}" = "rm" -o "${OVERWRITE}" = "dry-rm" ] && continue 1
        #
        #----- combine necessary input file
        #
        echo "YMD=${YMD}"
        grads_get_data.sh ${VERBOSE_OPT} ${INPUT_CTL}      ${VAR}      ${TEMP_DIR}/${VAR}_${YMD}.grd.in \
            -ymd "(${YMD}:${YMDPP}]" || exit 1   # one day = [00:01 - 24:00]
        grads_get_data.sh ${VERBOSE_OPT} ${INPUT_PRES_CTL} ${VAR_PRES} ${TEMP_DIR}/${VAR_PRES}_${YMD}.grd.in \
            -ymd "(${YMD}:${YMDPP}]" || exit 1   # one day = [00:01 - 24:00]
	#
	#----- z2pre
	#
	NOTHING=0
	cd ${TEMP_DIR}
	cat > z2pre.cnf <<EOF
&Z2PRE_PARAM
    imax      = ${XDEF},        ! grid number for x-axis
    jmax      = ${YDEF},        ! grid number for y-axis
    kmax      = ${ZDEF},        ! vertical grid number (in z coordinate) of original data 
    pmax      = ${PDEF},        ! vertical grid number (in pressure coordinate) of output data 
    tmax      = ${TDEF_FILE},   ! 
    varmax    = 1,              ! total variable number 
    undef     = -99.9e+33,      !
    plevel    = ${PDEF_LEVELS}, !
    indir     = '.',                           ! input directory name
    varname   = '${VAR}',
    insuffix  = '_${YMD}.grd.in',              ! suffix of original data
    pname     = '${VAR_PRES}_${YMD}.grd.in',   ! pressure data in z-coordinate
    outdir    = '.',                           ! output directory name
    outsuffix = '_${YMD}.grd',                 ! suffix of output data
/
EOF
	if [ ${VERBOSE} -ge 1 ] ; then
	    [ ${VERBOSE} -ge 2 ] && cat z2pre.cnf
	    ${BIN_Z2PRE} || exit 1
	else
	    ${BIN_Z2PRE} > /dev/null || exit 1
	fi
	#
	mv ${VAR}_${YMD}.grd ../${OUTPUT_DIR}/${VAR}/${YEAR}/ || exit 1
	mv z2pre.cnf         ../${OUTPUT_DIR}/${VAR}/log/z2pre_${YMD}.cnf
	rm -f ${VAR}_${YMD}.grd.in ${VAR_PRES}_${YMD}.grd.in
	cd - > /dev/null || exit 1
	
    done  # date loop

done  # variable loop

[ ${NOTHING} -eq 1 ] && echo "info: Nothing to do."
echo "$0 normally finished."
echo