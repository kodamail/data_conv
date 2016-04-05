#!/bin/sh
#
# monthly mean
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
    TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_CTL} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
    SUBVARS=( $(      grads_ctl.pl ${INPUT_CTL} VARS ALL ) ) || exit 1
    VDEF=${#SUBVARS[@]}
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
    mkdir -p ${OUTPUT_DIR}/${VAR}/log || exit 1
    grads_ctl.pl ${INPUT_CTL} > ${OUTPUT_CTL}.tmp1 || exit 1
    #
    STR_ENS=""
    [ ${EDEF} -gt 1 ] && STR_ENS="_bin%e"
    #
    YM=$( date -u --date "${TDEF_START}" +%Y%m ) || exit 1
    let TDEF_SEC=TDEF_INCRE_SEC*${TDEF}
    OUTPUT_YM_END=$( date -u --date "${TDEF_START} ${TDEF_SEC} seconds 1 month ago" +%Y%m ) || exit 1
    OUTPUT_TDEF=0
    while [ ${YM} -le ${OUTPUT_YM_END} ] ; do
	let OUTPUT_TDEF=OUTPUT_TDEF+1
	YM=$( date -u --date "${YM}01 1 month" +%Y%m )
    done
    OUTPUT_TDEF_START=15$( date -u --date "${TDEF_START}" +%b%Y ) || exit 1
    sed ${OUTPUT_CTL}.tmp1 \
        -e "s|^DSET .*$|DSET ^%y4/${VAR}_%y4%m2${STR_ENS}.grd|" \
	-e "s/TEMPLATE//ig" \
        -e "s/^OPTIONS .*$/OPTIONS TEMPLATE BIG_ENDIAN/i" \
        -e "s/ yrev//i" \
	-e "s/^UNDEF .*$/UNDEF -0.99900E+35/i"  \
        -e "s/^TDEF .*$/TDEF    ${OUTPUT_TDEF}  LINEAR  ${OUTPUT_TDEF_START}  1mo/" \
        -e "s/^ -1,40,1 / 99 /" \
        -e "/^CHSUB .*$/d" \
	> ${OUTPUT_CTL} || exit 1
    rm ${OUTPUT_CTL}.tmp1
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
#	    [ ! -d ${OUTPUT_DIR}/${VAR} ] && mkdir -p ${OUTPUT_DIR}/${VAR}
	    if [ -f ${OUTPUT_DATA} ] ; then
		SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' ) || exit 1
		SIZE_OUT_EXACT=$( echo "4*${XDEF}*${YDEF}*${ZDEF}*${VDEF}" | bc ) || exit 1
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
	if [ "${START_HMS}" != "000000" ] ; then
            TMIN=$( grads_time2t.sh ${INPUT_CTL} ${YM}01   -gt ) || exit 1
            TMAX=$( grads_time2t.sh ${INPUT_CTL} ${YMPP}01 -le ) || exit 1
	else
            TMIN=$( grads_time2t.sh ${INPUT_CTL} ${YM}01   -ge ) || exit 1
            TMAX=$( grads_time2t.sh ${INPUT_CTL} ${YMPP}01 -lt ) || exit 1
	    echo "It is not fully checked. Please check!"
	    exit 1
	fi
	echo "YM=${YM} (TMIN=${TMIN}, TMAX=${TMAX})"
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
	    rm -f temp.grd temp2.grd
	    for SUBVAR in ${SUBVARS[@]} ; do
		cat > temp.gs <<EOF
'reinit'
rc = gsfallow('on')
'xopen ../${INPUT_CTL}'
'set gxout fwrite'
'set fwrite -be temp2.grd'
'set undef -0.99900E+35'
'set x 1 ${XDEF}'
'set y 1 ${YDEF}'
'set e ${e}'
z = 1
while( z <= ${ZDEF} )
  prex( 'set z 'z )
  prex( 'd ave(${SUBVAR},t=${TMIN},t=${TMAX})' )
  z = z + 1
endwhile
'disable fwrite'
'quit'
EOF
		if [ ${VERBOSE} -ge 1 ] ; then
		    [ ${VERBOSE} -ge 2 ] && cat temp.gs
		    grads -blc temp.gs || exit 1
		else
		    grads -blc temp.gs > temp.log || { cat temp.log ; exit 1 ; }
		fi
		#
		cat temp2.grd >> temp.grd || exit 1
		rm temp2.grd temp.gs
	    done
	    mv temp.grd ../${OUTPUT_DATA} || exit 1

	done
	cd - > /dev/null || exit 1

    done  # year/month loop

done  # variable loop

[ ${NOTHING} -eq 1 ] && echo "info: Nothing to do."
echo "$0 normally finished."
echo
