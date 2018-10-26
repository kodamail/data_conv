#!/bin/sh
#
# derive variables
#
echo "########## $0 start ##########"
set -x
CNFID=$1       # CNFID (e.g. "def")
START_YMD=$2   # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$3   # YYYYMMDD (end+1 day of analysis period)
INPUT_DIR=$4   # input dir
OUTPUT_DIR=$5  # output dir
OVERWRITE=$6   # overwrite option (optional)
TARGET_VAR=$7
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
    echo "error: VAR is not set." >&2
    exit 1
fi

VAR_LIST=( ${TARGET_VAR} )

NOTHING=1
#============================================================#
#
#  variable loop
#
#============================================================#
for VAR in ${VAR_LIST[@]} ; do
    #
    # SA
    #   s: snapshot  a: average
    #
    [ "${SA}" = "" ] && SA=${VAR:1:1}
    #
    #----- check whether output dir is write-protected
    #
    if [ -f "${INPUT_DIR}/${VAR}/_locked" ] ; then
	echo "info: ${INPUT_DIR} is locked."
	continue
    fi
    case "${VAR}" in
	"s${SA}_ws10m")
	    INPUT_CTL_LIST=( 
		${INPUT_DIR}/s${SA}_u10m/s${SA}_u10m.ctl
		${INPUT_DIR}/s${SA}_v10m/s${SA}_v10m.ctl
		)
#	    INPUT_VAR_REF=ss_u10m
	    GRADS_VAR="sqrt(s${SA}_u10m.1*s${SA}_u10m.1+s${SA}_v10m.2*s${SA}_v10m.2)"
	    ;;
	"m${SA}_ws")
	    INPUT_CTL_LIST=( 
		${INPUT_DIR}/m${SA}_u/m${SA}_u.ctl
		${INPUT_DIR}/m${SA}_v/m${SA}_v.ctl
	    )
	    #		INPUT_VAR_REF=ms_u_p850
	    GRADS_VAR="sqrt(m${SA}_u.1*m${SA}_u.1+m${SA}_v.2*m${SA}_v.2)"
	    ;;
    esac
    INPUT_CTL_REF=${INPUT_CTL_LIST[0]}

    for INPUT_CTL in ${INPUT_CTL_LIST[@]} ; do
	if [ ! -f "${INPUT_CTL}" ] ; then
	    echo "warning: ${INPUT_CTL} does not exist."
	    continue 2
	fi
    done
    #
    #----- check existence of output data
    #
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
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
    DIMS=( $( grads_ctl.pl ${INPUT_CTL_REF} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}
    TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    TDEF_START=$(     grads_ctl.pl ${INPUT_CTL_REF} TDEF 1 ) || exit 1
    TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_CTL_REF} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
    TDEF_INCRE_MN=$(  grads_ctl.pl ${INPUT_CTL_REF} TDEF INC --unit MN  | sed -e "s/MN//"  ) || exit 1
    #
    START_HMS=$( date -u --date "${TDEF_START}" +%H%M%S )
    TMP_H=${START_HMS:0:2}
    TMP_M=${START_HMS:2:2}
    let TMP_MN=TMP_H*60+TMP_M
    let TDEF_FILE=60*60*24/TDEF_INCRE_SEC       # number of time step per file
    let TDEF_SEC_FILE=TDEF_INCRE_SEC*TDEF_FILE  # time in second per file
    #
    #----- check existence of input data
    #
    for INPUT_CTL in ${INPUT_CTL_LIST[@]} ; do
	if [ "${START_HMS}" != "000000" ] ; then
	    FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
	else
	    FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "[${START_YMD}:${ENDPP_YMD})" ) ) || exit 1
	fi
	if [ "${FLAG[0]}" != "ok" ] ; then
	    echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})."
	    continue 2
	fi
    #
    done
    #
    #---- generate control file (unified)
    #
    mkdir -p ${OUTPUT_DIR}/${VAR}/log || exit 1
    if [ "${START_HMS}" != "000000" ] ; then
	DSET="DSET ^%ch/${VAR}.grd"
    else
	DSET="DSET ^%y4/${VAR}_%y4%m2%d2.grd"
    fi
    grads_ctl.pl ${INPUT_CTL_REF}    \
	--set "${DSET}" \
	--set "OPTIONS template big_endian" \
	--set "UNDEF -0.99900E+35"   \
	| sed -e "/^VARS/,/^ENDVARS/d" \
	> ${OUTPUT_CTL} || exit 1
    cat >> ${OUTPUT_CTL} <<EOF
VARS 1
${VAR} ${ZDEF} 99 ${VAR}
ENDVARS
EOF
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
        if [ "${START_HMS}" != "000000" ] ; then
	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${YMD}.000000-${YMDPP}.000000/${VAR}.grd
	else
	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YMD}.grd
	fi
#        mkdir -p ${INPUT_DIR}/${VAR}/${YEAR}/${YMD}.000000-${YMDPP}.000000 || exit 1
        mkdir -p ${OUTPUT_DATA%/*} || exit 1
	#
        #----- output file exist?
	#
	if [ -f "${OUTPUT_DATA}" ] ; then
	    SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' ) || exit 1
	    SIZE_OUT_EXACT=$( echo 4*${XDEF}*${YDEF}*${ZDEF}*${TDEF_FILE} | bc ) || exit 1
#	    SIZE_OUT_EXACT=$( echo 4*${XDEF}*${YDEF}*1*${TDEF_FILE} | bc ) || exit 1
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
	echo "YMD=${YMD}"
	#
	# derive
	#
	NOTHING=0
        if [ "${START_HMS}" != "000000" ] ; then
            TMIN=$( grads_time2t.sh ${INPUT_CTL} ${YMD}   -gt ) || exit 1
            TMAX=$( grads_time2t.sh ${INPUT_CTL} ${YMDPP} -le ) || exit 1
        else
            TMIN=$( grads_time2t.sh ${INPUT_CTL} ${YMD}   -ge ) || exit 1
            TMAX=$( grads_time2t.sh ${INPUT_CTL} ${YMDPP} -lt ) || exit 1
        fi
	cd ${TEMP_DIR}
	cat > temp.gs <<EOF
'reinit'
rc = gsfallow( 'on' )
EOF
	for INPUT_CTL in ${INPUT_CTL_LIST[@]} ; do
	    echo "'xopen ../${INPUT_CTL}'" >> temp.gs
	done
	cat >> temp.gs <<EOF
'set gxout fwrite'
'set fwrite -be ${VAR}_${YMD}.grd'
'set undef -0.99900E+35'
'set x 1 ${XDEF}'
'set y 1 ${YDEF}'
'set z 1'
t = ${TMIN}
while( t <= ${TMAX} )
  prex( 'set t 't )
  z = 1
  while( z <= ${ZDEF} )
    prex( '  set z 'z )
    'd ${GRADS_VAR}'
    z = z + 1
endwhile
  t = t + 1
endwhile
'quit'
EOF
	grads -blc temp.gs || exit 1
	mv ${VAR}_${YMD}.grd ../${OUTPUT_DATA} || exit 1
	mv temp.gs           ../${OUTPUT_DIR}/${VAR}/log/derive_${YMD}.gs
	cd - > /dev/null || exit 1

    done  # date loop

done  # variable loop

[ ${NOTHING} -eq 1 ] && echo "info: Nothing to do."
echo "$0 normally finished."
echo
