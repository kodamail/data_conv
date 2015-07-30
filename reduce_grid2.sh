#!/bin/sh
#
# reduce horizontal grid
#
. ./common.sh || exit 1

echo "########## $0 start ##########"
set -x
START_YMD=$1    # date (YYYYMMDD)
ENDPP_YMD=$2    # date (YYYYMMDD)
INPUT_DIR=$3
OUTPUT_DIR=$4
XYDEF=$5
OVERWRITE=$6   # optional
TARGET_VAR=$7  # optional
set +x
echo "##########"

create_temp || exit 1
TEMP_DIR=${BASH_COMMON_TEMP_DIR}
trap "finish" 0

if [   "${OVERWRITE}" != ""       \
    -a "${OVERWRITE}" != "yes"    \
    -a "${OVERWRITE}" != "no"     \
    -a "${OVERWRITE}" != "dry-rm" \
    -a "${OVERWRITE}" != "rm"     ] ; then
    echo "error: OVERWRITE = ${OVERWRITE} is not supported yet." >&2
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
        FLAG=( $( exist_data.sh ${OUTPUT_CTL} \
            $( time_2_grads ${START_YMD} )    \
            $( time_2_grads ${ENDPP_YMD} ) "PP" ) ) || exit 1
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
    FLAG=( $( exist_data.sh ${INPUT_CTL} \
	$( time_2_grads ${START_YMD} )   \
	$( time_2_grads ${ENDPP_YMD} ) "PP" ) ) || exit 1
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
    DIMS=( $( grads_ctl.pl ${INPUT_CTL} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]} ; TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    TDEF_START=$(     grads_ctl.pl ${INPUT_CTL} TDEF 1 ) || exit 1
    TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_CTL} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
    TDEF_INCRE_MN=$(  grads_ctl.pl ${INPUT_CTL} TDEF INC --unit MN  | sed -e "s/MN//"  ) || exit 1
    #
    XDEF_OUT=$( echo ${XYDEF} | cut -d x -f 1 )
    YDEF_OUT=$( echo ${XYDEF} | cut -d x -f 2 )
    let OUTPUT_TDEF_ONEFILE=60*60*24/TDEF_INCRE_SEC   # per one file
    mkdir -p ${OUTPUT_DIR}/${VAR}/log || exit 1
    #
    # generate control file (unified)
    #
    grads_ctl.pl ${INPUT_CTL} > ${OUTPUT_CTL}.tmp1 || exit 1
    #
    XDEF_OUT_START=$( echo "scale=7; 360 / ${XDEF_OUT} / 2"       | bc )
    XDEF_OUT_INT=$(   echo "scale=7; 360.0 / ${XDEF_OUT}"         | bc )
    #
    # if YDEF is odd  -> [-90:90]
    # if YDEF is even -> [-8_:8_] (default in roughen)
    let YDEF_OUT_TMP=YDEF_OUT/2*2
    if [ ${YDEF_OUT} -ne ${YDEF_OUT_TMP} ] ; then
	YDEF_OUT_START="-90.0"
	YDEF_OUT_END="90.0"
	YDEF_OUT_INT=$(   echo "scale=7; 180.0 / (${YDEF_OUT}-1)"     | bc )
    else
	YDEF_OUT_START=$( echo "scale=7; -90 + 180 / ${YDEF_OUT} / 2" | bc )
	YDEF_OUT_END=$( echo "scale=7;  90 - 180 / ${YDEF_OUT} / 2" | bc )
	YDEF_OUT_INT=$(   echo "scale=7; 180.0 / ${YDEF_OUT}"         | bc )
    fi
    #
    let TDEF_ONEFILE_INCRE_SEC=TDEF_INCRE_SEC*OUTPUT_TDEF_ONEFILE
    #
    rm -f ${OUTPUT_CTL}.chsub
    DATE=$( date -u --date "${TDEF_START}" +%Y%m%d\ %H:%M:%S )  # YYYYMMDD HH:MM:SS
    echo "CHSUB  1  ${OUTPUT_TDEF_ONEFILE}  ${DATE:0:4}/${VAR}_${DATE:0:8}" >> ${OUTPUT_CTL}.chsub    
    for(( d=1+${OUTPUT_TDEF_ONEFILE}; ${d}<=${TDEF}; d=${d}+${OUTPUT_TDEF_ONEFILE} )) ; do
	let CHSUB_MAX=d+OUTPUT_TDEF_ONEFILE-1
	DATE=$( date -u --date "${DATE} ${TDEF_ONEFILE_INCRE_SEC} seconds" +%Y%m%d\ %H:%M:%S )
	echo "CHSUB  ${d}  ${CHSUB_MAX}  ${DATE:0:4}/${VAR}_${DATE:0:8}" >> ${OUTPUT_CTL}.chsub
    done
    sed ${OUTPUT_CTL}.tmp1 \
        -e "s|^DSET .*$|DSET \^%ch.grd|" \
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
        -e "s/^TDEF .*$/TDEF    ${TDEF}  LINEAR  ${TDEF_START}  ${TDEF_INCRE_MN}mn/" \
	> ${OUTPUT_CTL}.tmp
    sed -e "/^DSET/q" ${OUTPUT_CTL}.tmp   > ${OUTPUT_CTL}
    cat ${OUTPUT_CTL}.chsub               >> ${OUTPUT_CTL}
    sed -e "0,/^DSET/d" ${OUTPUT_CTL}.tmp >> ${OUTPUT_CTL}
    rm ${OUTPUT_CTL}.tmp ${OUTPUT_CTL}.tmp1 ${OUTPUT_CTL}.chsub
#    cat ${OUTPUT_CTL}

    #=====================================#
    #      date loop (for each file)      #
    #=====================================#
    for(( d=1; ${d}<=${TDEF}; d=${d}+${OUTPUT_TDEF_ONEFILE} )) ; do
	#
	#----- set/proceed date -----#
	#
	if [ ${d} -eq 1 ] ; then
	    DATE=$( date -u --date "${TDEF_START}" +%Y%m%d\ %H:%M:%S )
	else
	    DATE=$( date -u --date "${DATE} ${TDEF_ONEFILE_INCRE_SEC} seconds" +%Y%m%d\ %H:%M:%S )
	fi
	YMD=${DATE:0:8}
	YMDPP=$( date -u --date "${YMD} 1 day" +%Y%m%d )
	#
	[ ${YMD} -lt ${START_YMD} ] && continue
	[ ${YMD} -ge ${ENDPP_YMD} ] && break
	#
	YEAR=${DATE:0:4} ; MONTH=${DATE:4:2} ; DAY=${DATE:6:2}
	#
        #----- output data -----#
        #
        # File name convention
        #   2004/ms_tem_20040601.grd  (center of the date if incre > 1dy)
	#
	OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YMD}.grd
        mkdir -p ${OUTPUT_DIR}/${VAR}/${YEAR}
	#
        # output file exist?
	if [ -f ${OUTPUT_DATA} ] ; then
	    SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' )
	    SIZE_OUT_EXACT=$( echo 4*${XDEF_OUT}*${YDEF_OUT}*${ZDEF}*${OUTPUT_TDEF_ONEFILE} | bc )
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
	echo "YMD=${YMD}"
	get_data.sh -v ${INPUT_CTL} ${VAR} ${TEMP_DIR}/${VAR}_${YMD}.grd.in \
	    -ymd "(${YMD}:${YMDPP}]" || exit 1   # one day = [00:01 - 24:00]
	#
	#----- roughen -----#
        # assuming globally uniform grid
	#
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
    tmax          = ${OUTPUT_TDEF_ONEFILE}, ! time
    varmax        = 1,                  ! variable number
    varname       = '${VAR}',
    undef         = -99.9e+33,
    latmin_out    = ${YDEF_OUT_START},
    latmax_out    = ${YDEF_OUT_END},
/
EOF

#	let YDEF_OUT_TMP=YDEF_OUT/2*2
#	if [ ${YDEF_OUT} -ne ${YDEF_OUT_TMP} ] ; then
#	    cat >> roughen.cnf <<EOF
#    latmin_out    = -90.0,
#    latmax_out    = 90.0,
#EOF
#	fi
#	echo "/" >> roughen.cnf
	#
        ${BIN_ROUGHEN} || exit 1
	#
	mv ${VAR}_${YMD}.grd ../${OUTPUT_DIR}/${VAR}/${YEAR}/ || exit 1
	mv roughen.cnf       ../${OUTPUT_DIR}/${VAR}/log/roughen_${YMD}.cnf
	rm ${VAR}_${YMD}.grd.in
	cd - > /dev/null || exit 1

    done   # date loop

done  # var loop


if [ ${NOTHING} -eq 1 ] ; then
    echo "info: Nothing to do."
fi

echo "$0 normally finished."
