#!/bin/sh
#
# 7x7 -> high/middle/low
#
echo "########## $0 start ##########"
set -x
CNFID=$1       # CNFID (e.g. "def")
START_YMD=$2   # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$3   # YYYYMMDD (end+1 day of analysis period)
INPUT_DIR=$4   # input dir
OUTPUT_DIR=$5  # output dir
OVERWRITE=$6   # overwrite option (optional)
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

VAR_LIST=( dfq_isccp2 )

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
    if [ ${ZDEF} -ne 49 ] ; then
	echo "error: ZDEF (=${ZDEF}) should be 49."
	exit 1
    fi
    TDEF_START=$(     grads_ctl.pl ${INPUT_CTL} TDEF 1 ) || exit 1
    TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_CTL} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
    TDEF_INCRE_MN=$(  grads_ctl.pl ${INPUT_CTL} TDEF INC --unit MN  | sed -e "s/MN//"  ) || exit 1
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
    if [ "${OVERWRITE}" != "rm" -a "${OVERWRITE}" != "dry-rm" ] ; then
	grads_ctl.pl ${INPUT_CTL} > ${OUTPUT_CTL}.tmp1 || exit 1
        #
	sed ${OUTPUT_CTL}.tmp1 \
            -e "/^CHSUB .*/d"  \
            -e "s/TEMPLATE//ig" \
            -e "s/^OPTIONS .*/OPTIONS TEMPLATE BIG_ENDIAN/i" \
            -e "s/^UNDEF .*$/UNDEF -0.99900E+35/i"  \
            -e "/^ZDEF/,/^TDEF/{" \
            -e "/^\(ZDEF\|TDEF\)/!D" \
            -e "}" \
            -e "s/^ZDEF.*/ZDEF  3  LEVELS  1.0  2.0  3.0/" \
            -e "s/^\(${VAR} *\)${ZDEF}/\13/" \
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
	echo "* z=1: low-level cloud"         >> ${OUTPUT_CTL} || exit 1
	echo "* z=2: middle-level cloud"      >> ${OUTPUT_CTL} || exit 1
	echo "* z=3: high-level cloud"        >> ${OUTPUT_CTL} || exit 1
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
            SIZE_OUT_EXACT=$( echo 4*${XDEF}*${YDEF}*3*${TDEF_FILE} | bc ) || exit 1
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
	# sum up
	#
        NOTHING=0
        echo "YMD=${YMD}"
        if [ "${START_HMS}" != "000000" ] ; then
            TMIN=$( grads_time2t.sh ${INPUT_CTL} ${YMD}   -gt ) || exit 1
            TMAX=$( grads_time2t.sh ${INPUT_CTL} ${YMDPP} -le ) || exit 1
	else
            TMIN=$( grads_time2t.sh ${INPUT_CTL} ${YMD}   -ge ) || exit 1
            TMAX=$( grads_time2t.sh ${INPUT_CTL} ${YMDPP} -lt ) || exit 1
	    echo "It is not fully checked until now. Please check!"
	    exit 1
	fi
	#
	cd ${TEMP_DIR}
	cat > temp.gs <<EOF
'reinit'
'xopen ../${INPUT_CTL}'
'set gxout fwrite'
'set fwrite -be ${VAR}_${YMD}.grd'
*'set undef dfile'
'set undef -0.99900E+35'
'set x 1 ${XDEF}'
'set y 1 ${YDEF}'
'set z 1'
t = ${TMIN}
while( t <= ${TMAX} )
  say t
  'set t 't
* low cloud
  'd sum(${VAR},z=37,z=42)+sum(${VAR},z=44,z=49)'
* middle cloud
  'd sum(${VAR},z=23,z=28)+sum(${VAR},z=30,z=35)'
* high cloud
  'd sum(${VAR},z=2,z=7)+sum(${VAR},z=9,z=14)+sum(${VAR},z=16,z=21)'
  t = t + 1
endwhile
'quit'
EOF
	if [ ${VERBOSE} -ge 1 ] ; then
	    [ ${VERBOSE} -ge 2 ] && cat temp.gs
	    grads -blc temp.gs || exit 1
	else
	    grads -blc temp.gs > temp.log || { cat temp.log ; exit 1 ; }
	fi
	#
	mv ${VAR}_${YMD}.grd ../${OUTPUT_DIR}/${VAR}/${YEAR}/ || exit 1
	mv temp.gs           ../${OUTPUT_DIR}/${VAR}/log/temp_${YMD}.gs
	cd - > /dev/null || exit 1

    done  # date loop

done  # variable loop

[ ${NOTHING} -eq 1 ] && echo "info: Nothing to do."
echo "$0 normally finished."
echo
