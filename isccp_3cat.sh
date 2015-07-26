#!/bin/sh
#
. ./common.sh     || exit 1
#. ./usr/common.sh || exit 1

echo "########## $0 start ##########"
set -x
#DAYS=$1
START_DATE=$1  # date (YYYYMMDD)
ENDPP_DATE=$2  # date (YYYYMMDD)
INPUT_DIR=$3
OUTPUT_DIR=$4
OVERWRITE=$5   # optional
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
    echo "error: OVERWRITE = ${OVERWRITE} is not supported yet"
    exit 1
fi

VAR_LIST=( dfq_isccp2 )

NOTHING=1
#=====================================#
#      var loop                       #
#=====================================#
for VAR in ${VAR_LIST[@]} ; do
    #
    # check output dir
    #
    if [ -f "${OUTPUT_DIR}/${VAR}/_locked" ] ; then
        echo "info: ${OUTPUT_DIR} is locked"
        continue
    fi
    #
    # check input data
    #
    INPUT_CTL=${INPUT_DIR}/${VAR}/${VAR}.ctl
    if [ ! -f ${INPUT_CTL} ] ; then
        echo "warning: ${INPUT_CTL} does not exist"
        #echo "##########"
        continue
    fi
    FLAG=( $( exist_data.sh \
        ${INPUT_CTL} \
        $( time_2_grads ${START_DATE} ) \
        $( time_2_grads ${ENDPP_DATE} ) \
        "PP" ) ) || exit 1
    if [ "${FLAG[0]}" != "ok" ] ; then
        echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})"
        #echo "##########"
        continue
    fi
    EXT=grd
    TMP=$( echo "${FLAG[1]}" | grep ".nc$" )
    OPT_NC=""
    if [ "${TMP}" != "" ] ; then
        EXT=nc
        INPUT_NC_1=${FLAG[1]}
        OPT_NC="nc=${FLAG[1]}"
    fi

    #
    # get number of grid
    #
    DIMS=( $( ${BIN_GRADS_CTL} ${INPUT_CTL} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]} ; TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
#    XDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=XDEF target=NUM ) || exit 1
#    YDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=YDEF target=NUM ) || exit 1
#    ZDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=ZDEF target=NUM ) || exit 1
    if [ ${ZDEF} -ne 49 ] ; then
	echo "error: ZDEF (=${ZDEF}) should be 49"
	echo "##########"
	exit 1
    fi
#    TDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=NUM ) || exit 1
    TDEF_START=$( ${BIN_GRADS_CTL} ${INPUT_CTL} TDEF 1 ) || exit 1
    TDEF_INCRE_SEC=$( ${BIN_GRADS_CTL} ${INPUT_CTL} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
    TDEF_INCRE_MN=$( ${BIN_GRADS_CTL} ${INPUT_CTL} TDEF INC --unit MN | sed -e "s/MN//" ) || exit 1
    #
#    TDEF_START=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=1 ) || exit 1
#    TDEF_INCRE_SEC=$( grads_ctl.pl ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=STEP unit=SEC | sed -e "s/SEC//" ) || exit 1
#    TDEF_INCRE_MN=$( grads_ctl.pl ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=STEP unit=MN | sed -e "s/MN//" ) || exit 1
    #
    OUTPUT_TDEF_ONEFILE=$( echo "60 * 60 * 24 / ${TDEF_INCRE_SEC}" | bc ) || exit 1   # per one file
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
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
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
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
        echo "CHSUB  ${CHSUB_MIN}  ${CHSUB_MAX}  ${YEAR}/${DATE}" >> ${OUTPUT_CTL}.chsub
    done
    sed ${OUTPUT_CTL}.tmp1 \
        -e "s|^DSET .*$|DSET \^%ch/${VAR}.grd|" \
        -e "/^CHSUB .*/d"  \
        -e "s/TEMPLATE//ig" \
        -e "s/^OPTIONS /OPTIONS TEMPLATE /i" \
        -e "s/^UNDEF .*$/UNDEF -0.99900E+35/i"  \
        -e "/^ZDEF/,/^TDEF/{" \
        -e "/^\(ZDEF\|TDEF\)/!D" \
        -e "}" \
        -e "s/^ZDEF.*/ZDEF  3  LEVELS  1.0  2.0  3.0/" \
        -e "s/^TDEF .*$/TDEF    ${TDEF}  LINEAR  ${TDEF_START}  ${TDEF_INCRE_MN}mn/" \
        -e "s/^\(${VAR} *\)${ZDEF}/\13/" \
        > ${OUTPUT_CTL}.tmp || exit 1
    sed -e "/^DSET/q" ${OUTPUT_CTL}.tmp   >  ${OUTPUT_CTL} || exit 1
    cat ${OUTPUT_CTL}.chsub               >> ${OUTPUT_CTL} || exit 1
    sed -e "0,/^DSET/d" ${OUTPUT_CTL}.tmp >> ${OUTPUT_CTL} || exit 1
    echo "* z=1: low-level cloud"         >> ${OUTPUT_CTL} || exit 1
    echo "* z=2: middle-level cloud"      >> ${OUTPUT_CTL} || exit 1
    echo "* z=3: high-level cloud"        >> ${OUTPUT_CTL} || exit 1
    rm ${OUTPUT_CTL}.tmp ${OUTPUT_CTL}.tmp1 ${OUTPUT_CTL}.chsub

    #=====================================#
    #      date loop (for each file)      #
    #=====================================#
    for(( d=1; ${d}<=${TDEF}; d=${d}+${OUTPUT_TDEF_ONEFILE} )) ; do
        if [ ${d} -eq 1 ] ; then
            DATE_GRADS=${TDEF_START}
        else
            for(( dd=1; ${dd}<=${OUTPUT_TDEF_ONEFILE}; dd=${dd}+1 )) ; do
                DATE_GRADS=$( date -u --date "${DATE_GRADS} ${TDEF_INCRE_SEC} seconds" +%H:%Mz%d%b%Y\
 ) || exit 1
            done
        fi
        DATE=$(     date -u --date "${DATE_GRADS}" +%Y%m%d ) || exit 1
        DATE_SEC=$( date -u --date "${DATE_GRADS}" +%s )     || exit 1
        TMP_SEC_MIN=$(  date -u --date "00:00z${START_DATE}" +%s ) || exit 1
        TMP_SEC_MAX=$(  date -u --date "00:00z${ENDPP_DATE}" +%s ) || exit 1
        if [ ${TMP_SEC_MIN} -gt ${DATE_SEC} -o ${TMP_SEC_MAX} -lt ${DATE_SEC} ] ; then
            continue
	fi
	#
        #----- set date for ${DATE} -----#
	#
        YEAR=${DATE:0:4}
        MONTH=${DATE:4:2}
        DAY=${DATE:6:2}
	#
        TMIN=${d}
        TMAX=$( echo "${d}+${OUTPUT_TDEF_ONEFILE}-1" | bc ) || exit 1
	#
        #----- output data -----#
	#
	#
        # File name convention
        #   ms_tem_20040601.grd  (center of the date if incre > 1dy)
	#
        OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${DATE}/${VAR}.grd
        mkdir -p ${OUTPUT_DIR}/${VAR}/${YEAR}/${DATE}
	#
        # output file exist?
        if [ -f ${OUTPUT_DATA} ] ; then
            SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' ) || exit 1
            SIZE_OUT_EXACT=$( echo 4*${XDEF}*${YDEF}*3*${OUTPUT_TDEF_ONEFILE} | bc ) || exit 1
            if [   ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} \
                -a "${OVERWRITE}" != "yes" \
                -a "${OVERWRITE}" != "dry-rm" \
                -a "${OVERWRITE}" != "rm" ] ; then
                continue 1
            fi
            echo "Removing ${OUTPUT_DATA}"
            echo ""
            [ "${OVERWRITE}" = "dry-rm" ] && continue 1
            rm -f ${OUTPUT_DATA}
	fi
        [ "${OVERWRITE}" = "rm" -o "${OVERWRITE}" = "dry-rm" ] && exit
	
        NOTHING=0

        # sum up
	GS=${TEMP_DIR}/temp.gs
	cat > ${GS} <<EOF
'reinit'
'xopen ${INPUT_CTL}'
'set gxout fwrite'
'set fwrite -be ${TEMP_DIR}/temp.grd'
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
	grads -blc ${GS} || exit 1
	mv ${TEMP_DIR}/temp.grd ${OUTPUT_DATA} || exit 1
	mv ${GS} ${OUTPUT_DIR}/${VAR}/log/temp.gs.${YMD}
    done

done
if [ ${NOTHING} -eq 1 ] ; then
    echo "info: nothing to do"
fi

echo "$0 normally finished"
