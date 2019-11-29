#!/bin/bash
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

source ./common.sh ${CNFID} || exit 1

create_temp || exit 1
TEMP_DIR=${BASH_COMMON_TEMP_DIR}
trap "finish" 0

if [[ ! "${OVERWRITE}" =~ ^(|yes|no|dry-rm|rm)$ ]] ; then
    echo "error: OVERWRITE = ${OVERWRITE} is not supported yet." >&2
    exit 1
fi

if [[ "${TARGET_VAR}" = "" ]] ; then
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
    if [[ -f "${OUTPUT_DIR}/${VAR}/_locked" ]] ; then
	echo "info: ${OUTPUT_DIR} is locked."
	continue
    fi

#    #
#    #----- check existence of output data
#    # 
    mkdir -p ${OUTPUT_DIR}/${VAR}/log || exit 1
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
#    if [ -f "${OUTPUT_CTL}" -a "${OVERWRITE}" != "rm" -a "${OVERWRITE}" != "dry-rm" ] ; then
#        FLAG=( $( grads_exist_data.sh ${OUTPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
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
    INPUT_CTL_META=$( ctl_meta ${INPUT_CTL} ) || exit 1
    DIMS=( $( grads_ctl.pl ${INPUT_CTL_META} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}
    TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    TDEF_START=$(     grads_ctl.pl ${INPUT_CTL_META} TDEF 1 ) || exit 1
    TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_CTL_META} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
    TDEF_INCRE_MN=$(  grads_ctl.pl ${INPUT_CTL_META} TDEF INC --unit MN  | sed -e "s/MN//"  ) || exit 1
    #
    START_HMS=$( date -u --date "${TDEF_START}" +%H%M%S )
    TMP_H=${START_HMS:0:2}
    TMP_M=${START_HMS:2:2}
    let TMP_MN=TMP_H*60+TMP_M
    #
    #----- check existence of input data
    #
    if [[ "${START_HMS}" != "000000" ]] ; then
#	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
	TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${START_YMD} -gt ) || exit 1
	TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${ENDPP_YMD} -le ) || exit 1
    else
#	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "[${START_YMD}:${ENDPP_YMD})" ) ) || exit 1
	TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${START_YMD} -ge ) || exit 1
	TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${ENDPP_YMD} -lt ) || exit 1
    fi
#    if [ "${FLAG[0]}" != "ok" ] ; then
#	echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})."
#	continue
#    fi

    INPUT_DSET_LIST=( $( grads_ctl.pl ${INPUT_CTL} DSET "${TMIN}:${TMAX}" ) )
    INPUT_NC_LIST=()
    for INPUT_DSET in ${INPUT_DSET_LIST[@]} ; do
	INPUT_NC=$( readlink -e ${INPUT_DSET/^/${INPUT_CTL_META%/*}\//} ) \
	    || { echo "error: ${INPUT_DSET/^/${INPUT_CTL_META%/*}\//} does not exist." ; exit 1 ; }
	INPUT_NC_LIST+=( ${INPUT_NC} )
    done

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
    if [[ ! "${OVERWRITE}" =~ ^(dry-rm|rm)$ ]] ; then
	sed ${INPUT_CTL_META} \
	    -e "s|^DSET .*|DSET ^%ch.nc|" \
	    -e "/^CHSUB .*/d" \
	    > ${OUTPUT_CTL}
	grep ^CHSUB ${INPUT_CTL} | sed -e "s|/|/${VAR}_|" -e "s|.000000||g" -e "s|-.*$||" >> ${OUTPUT_CTL}

#	grads_ctl.pl ${INPUT_CTL} > ${OUTPUT_CTL}.tmp1 || exit 1
#        #
#	sed ${OUTPUT_CTL}.tmp1 \
#	    -e "/^CHSUB .*/d"  \
#            -e "s/^OPTIONS .*$/OPTIONS TEMPLATE BIG_ENDIAN/i" \
#	    -e "s/^UNDEF .*$/UNDEF -99.9e+33/" \
#            -e "/^XDEF/,/^YDEF/{" \
#            -e "/^\(XDEF\|YDEF\)/!D" \
#            -e "}" \
#            -e "s/^XDEF.*/XDEF  ${XDEF_OUT}  LINEAR  ${XDEF_OUT_START}  ${XDEF_OUT_INT}/" \
#            -e "/YDEF/,/^ZDEF/{" \
#            -e "/^\(YDEF\|ZDEF\)/!D" \
#            -e "}" \
#            -e "s/^YDEF.*/YDEF  ${YDEF_OUT}  LINEAR  ${YDEF_OUT_START}  ${YDEF_OUT_INT}/" \
#            -e "s/^VARS .*$/VARS  1/" \
#            -e "/^VARS/,/^ENDVARS/{" \
#            -e "/^\(VARS\|ENDVARS\|${VAR}\)/!D" \
#            -e "}" \
#	    > ${OUTPUT_CTL}.tmp2 || exit 1
#	if [ "${START_HMS}" != "000000" ] ; then
#	    rm -f ${OUTPUT_CTL}.chsub
#	    DATE=$( date -u --date "${TDEF_START}" +%Y%m%d\ %H:%M:%S ) || exit 1  # YYYYMMDD HH:MM:SS
#	    echo "CHSUB  1  ${TDEF_FILE}  ${DATE:0:4}/${VAR}_${DATE:0:8}" >> ${OUTPUT_CTL}.chsub    
#	    for(( d=1+${TDEF_FILE}; ${d}<=${TDEF}; d=${d}+${TDEF_FILE} )) ; do
#		let CHSUB_MAX=d+TDEF_FILE-1
#		DATE=$( date -u --date "${DATE} ${TDEF_SEC_FILE} seconds" +%Y%m%d\ %H:%M:%S ) || exit 1
#		echo "CHSUB  ${d}  ${CHSUB_MAX}  ${DATE:0:4}/${VAR}_${DATE:0:8}" >> ${OUTPUT_CTL}.chsub
#	    done
#	    sed ${OUTPUT_CTL}.tmp2 \
#		-e "s|^DSET .*$|DSET \^%ch.grd|" \
#		-e "s/^TDEF .*$/TDEF    ${TDEF}  LINEAR  ${TDEF_START}  ${TDEF_INCRE_MN}mn/" \
#		> ${OUTPUT_CTL}.tmp || exit 1
#	    sed -e "/^DSET/q" ${OUTPUT_CTL}.tmp    > ${OUTPUT_CTL} || exit 1
#	    cat ${OUTPUT_CTL}.chsub               >> ${OUTPUT_CTL} || exit 1
#	    sed -e "0,/^DSET/d" ${OUTPUT_CTL}.tmp >> ${OUTPUT_CTL} || exit 1
#	    rm ${OUTPUT_CTL}.tmp ${OUTPUT_CTL}.tmp[12] ${OUTPUT_CTL}.chsub
#	else
#	    sed ${OUTPUT_CTL}.tmp2 \
#		-e "s|^DSET .*$|DSET \^%y4/${VAR}_%y4%m2%d2.grd|" \
#		> ${OUTPUT_CTL} || exit 1
#	fi
#	rm -f ${OUTPUT_CTL}.tmp ${OUTPUT_CTL}.tmp[12] ${OUTPUT_CTL}.chsub
    fi

    #
    #========================================#
    #  loop for each file
    #========================================#
#    YMD_PREV=-1
    for INPUT_NC in ${INPUT_NC_LIST[@]} ; do
	TDEF_FILE=$( ${BIN_CDO} -s ntime ${INPUT_NC} )
	YMD_GRADS=$( grads_ctl.pl ${INPUT_NC} TDEF 1 )
        YMD=$( date -u --date "${YMD_GRADS}" +%Y%m%d ) || exit 1
#	(( ${YMD} == ${YMD_PREV} )) && { echo "error: time interval less than 1-dy is not supported now" ; exit 1 ; }
	YEAR=${YMD:0:4}
        #
        #----- output data
        #
        # File name convention (YMD = first day)
        #   2004/ms_tem_${YMD}.nc
        #
        OUTPUT_NC=$( readlink -m ${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YMD}.nc )
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
	mkdir -p ${OUTPUT_NC%/*} || exit 1
        echo "YMD=${YMD}"
	NOTHING=0
	#
	#----- roughen
	#
        # assuming globally uniform grid
	#
	cd ${TEMP_DIR}

	INSUFFIX=${INPUT_NC##*/${VAR}}
	cat > roughen.cnf <<EOF
&ROUGHEN_PARAM
    indir         = '${INPUT_NC%/*}',   ! input directory name
    insuffix      = '${INSUFFIX}',      ! suffix of original data
    input_netcdf  = .true.,

    outdir        = '.',                ! output directory name
    outsuffix     = '.nc',      ! suffix of output data
    output_netcdf = .true.,
    imax_out      = ${XDEF_OUT},        ! grid number for x-axis (output data)
    jmax_out      = ${YDEF_OUT},        ! grid number for y-axis (output data)

    varmax        = 1,                  ! variable number
    varname       = '${VAR}',
    latmin_out    = ${YDEF_OUT_START},
    latmax_out    = ${YDEF_OUT_END},

    opt_areaweight = .true.,
/
EOF
#	cat  roughen.cnf
        ${BIN_ROUGHEN} || exit 1
	#
	mv ${VAR}.nc ${OUTPUT_NC} || exit 1
	mv roughen.cnf ../${OUTPUT_DIR}/${VAR}/log/roughen_${YMD}.cnf
#	rm ${VAR}_${YMD}.grd.in
	cd - > /dev/null || exit 1
    done  # date loop

done  # variable loop

(( ${NOTHING} == 1 )) && echo "info: Nothing to do."
echo "$0 normally finished ($(date))."
echo
