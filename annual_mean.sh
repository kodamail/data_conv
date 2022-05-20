#!/bin/bash
#
# annual mean
#
echo "########## $0 start ##########"
set -x
CNFID=$1       # CNFID (e.g. "def")
START_YMD=$2   # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$3   # YYYYMMDD (end+1 day of analysis period)
INPUT_DIR=$4   # input dir
OUTPUT_DIR=$5  # output dir
OVERWRITE=$6   # overwrite option (optional)
INC_SUBVARS=$7 # SUBVARS option (optional)
TARGET_VAR=$8  # variable name (optional)
set +x
echo "##########"

. ./common.sh ${CNFID} || error_exit

create_temp || error_exit
TEMP_DIR=${BASH_COMMON_TEMP_DIR}
trap "finish" 0

if [[ ! "${OVERWRITE}" =~ ^(|yes|no|dry-rm|rm)$ ]] ; then
    echo "error: OVERWRITE = ${OVERWRITE} is not supported yet." >&2
    error_exit
fi

if [ "${TARGET_VAR}" = "" ] ; then
    VAR_LIST=( $( ls ${INPUT_DIR}/ ) ) || error_exit
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
    #
    #----- check existence of output data
    #
    Y_STARTMM=$( date -u --date "${START_YMD} 1 second ago" +%Y ) || error_exit
    Y_END=$(     date -u --date "${ENDPP_YMD} 1 year ago"   +%Y ) || error_exit

    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
    mkdir -p ${OUTPUT_DIR}/${VAR}/log || error_exit

#    if [ -f "${OUTPUT_CTL}" -a "${OVERWRITE}" != "rm" -a "${OVERWRITE}" != "dry-rm" ] ; then
#	YM_TMP=$(     date -u --date "${YM_STARTMM}01 1 month" +%Y%m ) || exit 1
#        FLAG=( $( grads_exist_data.sh ${OUTPUT_CTL} -ymd "[${YM_TMP}15:${YM_END}15]" ) ) || exit 1
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
    INPUT_CTL_META=$( ctl_meta ${INPUT_CTL} ) || error_exit
    DIMS=( $( grads_ctl.pl ${INPUT_CTL_META} DIMS NUM ) ) || error_exit
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}
    INPUT_TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    (( ${EDEF} > 1 )) && { echo "error: EDEF=${EDEF} is not supported in $0" ; error_exit ; }
    INPUT_TDEF_START=$(     grads_ctl.pl ${INPUT_CTL_META} TDEF 1 ) || error_exit
#    INPUT_TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_CTL_META} TDEF INC --unit SEC | sed -e "s/SEC//" ) || error_exit
#echo ${INPUT_TDEF_INCRE_SEC}
#exit 1
    SUBVARS=( ${VAR} )
    if [[ "${INC_SUBVARS}" = "yes" ]] ; then
	SUBVARS=( $( grads_ctl.pl ${INPUT_CTL_META} VARS ALL ) ) || error_exit
    fi
    VDEF=${#SUBVARS[@]}
    #
    START_HMS=$( date -u --date "${INPUT_TDEF_START}" +%H%M%S )
    TMP_H=${START_HMS:0:2}
    TMP_M=${START_HMS:2:2}
    let TMP_MN=TMP_H*60+TMP_M

    #
    #----- check existence of input data
    #
#    if [ "${START_HMS}" != "000000" ] ; then
#	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
#    else
#	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "[${START_YMD}:${ENDPP_YMD})" ) ) || exit 1
#    fi
#    if [ "${FLAG[0]}" != "ok" ] ; then
#        echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})."
#        continue
#    fi
    #
    #---- generate control file (unified)
    #
#    mkdir -p ${OUTPUT_DIR}/${VAR}/log || exit 1
    if [[ ! "${OVERWRITE}" =~ ^(dry-rm|rm)$ ]] ; then
	if [[ "${INC_SUBVARS}" = "yes" ]] ; then
	    grads_ctl.pl ${INPUT_CTL} > ${OUTPUT_CTL}.tmp1 || error_exit
	else
	    TMP=$( grads_ctl.pl ${INPUT_CTL} VARS | grep ^${VAR} )
#	    TMP=$( echo ${TMP} | awk '{ print $1, 99, }'sed -e "s///" )
	    TMP=$( echo ${TMP} | awk '{ out=$1" "$2" 99"; for(i=4;i<=NF; i++){ out=out" "$i } ; print out }' )
	    grads_ctl.pl ${INPUT_CTL} --set "VARS 1" --set "${TMP}" > ${OUTPUT_CTL}.tmp1 || error_exit
	fi
        #
	STR_ENS=""
	(( ${EDEF} > 1 )) && STR_ENS="_bin%e"
	#let OUTPUT_TDEF=INPUT_TDEF/12
	let OUTPUT_TDEF=Y_END-Y_STARTMM+1
	OUTPUT_TDEF_START=01Jun$( date -u --date "${INPUT_TDEF_START}" +%Y ) || error_exit

	sed ${OUTPUT_CTL}.tmp1 \
            -e "s|^DSET .*$|DSET ^${VAR}_%y4${STR_ENS}.grd|" \
	    -e "s/TEMPLATE//ig" \
            -e "s/^OPTIONS .*$/OPTIONS TEMPLATE BIG_ENDIAN/i" \
            -e "s/ yrev//i" \
	    -e "s/^UNDEF .*$/UNDEF -0.99900E+35/i"  \
            -e "s/^TDEF .*$/TDEF    ${OUTPUT_TDEF}  LINEAR  ${OUTPUT_TDEF_START}  1yr/" \
            -e "s/^ -1,40,1 / 99 /" \
            -e "/^CHSUB .*$/d" \
	    > ${OUTPUT_CTL} || error_exit
	rm ${OUTPUT_CTL}.tmp1
    fi
    #
    #========================================#
    #  month loop (for each file)
    #========================================#
    for(( Y=${Y_STARTMM}+1; ${Y}<=${Y_END}; Y=${Y}+1 )) ; do
	(( YPP=Y+1 ))
	#
        #----- output data
	#
        # File name convention
        #   ms_tem_2004.grd  (center of the date if incre > 1dy)
	#
        mkdir -p ${OUTPUT_DIR}/${VAR} || error_exit
	#
        # output file exist?
	for(( e=1; ${e}<=${EDEF}; e=${e}+1 )) ; do
	    STR_ENS=""
	    if (( ${EDEF} > 1 )) ; then
		STR_ENS=$( printf "%03d" ${e} ) || error_exit
		STR_ENS="_bin${STR_ENS}"
	    fi
	    #
	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_${Y}${STR_ENS}.grd
	    #
#	    [ ! -d ${OUTPUT_DIR}/${VAR} ] && mkdir -p ${OUTPUT_DIR}/${VAR}
	    if [[ -f "${OUTPUT_DATA}" ]] ; then
		SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' ) || error_exit
		SIZE_OUT_EXACT=$( echo "4*${XDEF}*${YDEF}*${ZDEF}*${VDEF}" | bc ) || error_exit
		if [ ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} -a "${OVERWRITE}" != "yes" \
		    -a "${OVERWRITE}" != "dry-rm" -a "${OVERWRITE}" != "rm" ] ; then
		    continue 2
		fi
		echo "Removing ${OUTPUT_DATA}."
		echo ""
		[[ "${OVERWRITE}" = "dry-rm" ]] && continue 1
		rm -f ${OUTPUT_DATA}
	    fi
	done
	[[ "${OVERWRITE}" = "rm" || "${OVERWRITE}" = "dry-rm" ]] && continue 1
	#
	# average
	#
	NOTHING=0
	if [[ "${START_HMS}" != "000000" ]] ; then
            TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${Y}0101   -gt ) || error_exit
            TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${YPP}0101 -le ) || error_exit
	else
            TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${Y}0101   -ge ) || error_exit
            TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${YPP}0101 -lt ) || error_exit
	fi
	echo "Y=${Y} (TMIN=${TMIN}, TMAX=${TMAX})"
	#
	cd ${TEMP_DIR}
	for(( e=1; ${e}<=${EDEF}; e=${e}+1 )) ; do
	    STR_ENS=""	
	    TEMPLATE_ENS=""
	    if (( ${EDEF} > 1 )) ; then
		STR_ENS=$( printf "%03d" ${e} ) || error_exit
		STR_ENS="_bin${STR_ENS}"
		TEMPLATE_ENS="_bin%e"
	    fi
	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_${Y}${STR_ENS}.grd
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
		if (( ${VERBOSE} >= 1 )) ; then
		    (( ${VERBOSE} >= 2 )) && cat temp.gs
		    grads -blc temp.gs || error_exit
		else
		    grads -blc temp.gs > temp.log || { cat temp.log ; error_exit ; }
		fi
		#
		cat temp2.grd >> temp.grd || error_exit
		rm temp2.grd temp.gs
	    done
	    mv temp.grd ../${OUTPUT_DATA} || error_exit

	done
	cd - > /dev/null || error_exit

    done  # year/month loop

done  # variable loop

(( ${NOTHING} == 1 )) && echo "info: Nothing to do."
echo "$0 normally finished ($(date))."
echo
