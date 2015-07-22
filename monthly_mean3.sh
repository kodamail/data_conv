#!/bin/sh
#
. ./common.sh     || exit 1
#. ./usr/common.sh || exit 1

echo "########## $0 start ##########"
set -x
START_DATE=$1    # date (YYYYMMDD)
ENDPP_DATE=$2    # date (YYYYMMDD)
INPUT_DIR=$3
OUTPUT_DIR=$4
OVERWRITE=$5   # optional
TARGET_VAR=$6   # optional
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

if [ "${TARGET_VAR}" = "" ] ; then
    VAR_LIST=( $( ls ${INPUT_DIR}/ ) )
else
    VAR_LIST=( ${TARGET_VAR} )
fi


NOTHING=1
#=====================================#
#            variable loop            #
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
	continue 2
    fi
    FLAG=( $( exist_data.sh \
	${INPUT_CTL} \
	$( time_2_grads ${START_DATE} ) \
	$( time_2_grads ${ENDPP_DATE} ) \
	"MMPP" ) )
    if [ "${FLAG[0]}" != "ok" ] ; then
	echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})"
	continue 2
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
    XDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=XDEF target=NUM )
    YDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=YDEF target=NUM )
    ZDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=ZDEF target=NUM )
    EDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=EDEF target=NUM )
    TDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=NUM )
    TDEF_START=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=1 )

    TDEF_INCRE_SEC=$( grads_ctl.pl ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=STEP unit=SEC | sed -e "s/SEC//" )
    SUBVARS=( $( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=VAR_LIST ) )
    VDEF=${#SUBVARS[@]}
    #
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
    [ ! -d ${OUTPUT_DIR}/${VAR}     ] && mkdir -p ${OUTPUT_DIR}/${VAR}
    [ ! -d ${OUTPUT_DIR}/${VAR}/log ] && mkdir -p ${OUTPUT_DIR}/${VAR}/log
    #
    #
    # generate control file (unified)
    #
    if [ "${EXT}" = "nc" ] ; then
	${BIN_NC2CTL} ${INPUT_NC_1} ${OUTPUT_CTL}.tmp1
    else
	cp ${INPUT_CTL} ${OUTPUT_CTL}.tmp1
    fi
    STR_ENS=""
    [ ${EDEF} -gt 1 ] && STR_ENS="_bin%e"

    CTL_TDEF_STR=$( grep TDEF ${OUTPUT_CTL}.tmp1 | awk '{ print $2,$3,$4 }' )
    TIME=$( date -u --date "${TDEF_START}" +%H:%Mz%d%b%Y )
    YYYYMM=$( date -u --date "${TIME}" +%Y%m )
    OUTPUT_TDEF=1
    OUTPUT_TDEF_START=15$( date -u --date "${TDEF_START}" +%b%Y )
    for(( i=2; $i<=${TDEF}; i=$i+1 )) ; do
	TIME=$( date -u --date "${TIME} ${TDEF_INCRE_SEC} seconds" +%H:%Mz%d%b%Y )
	YYYYMM_TMP=$( date -u --date "${TIME}" +%Y%m )
	if [ "${YYYYMM}" != "${YYYYMM_TMP}" ] ; then
	    OUTPUT_TDEF=$( expr ${OUTPUT_TDEF} + 1 )
	    YYYYMM=${YYYYMM_TMP}
	fi
    done
    TDEF_END=${TIME}
    sed ${OUTPUT_CTL}.tmp1 \
        -e "s/^DSET .*$/DSET ^${VAR}_%y4%m2${STR_ENS}.grd/" \
	-e "s/TEMPLATE//ig" \
        -e "s/^OPTIONS /OPTIONS TEMPLATE /i" \
        -e "/^OPTIONS yrev$/id" \
        -e "s/ yrev//i" \
	-e "s/^UNDEF .*$/UNDEF -0.99900E+35/i"  \
        -e "s/^TDEF .*$/TDEF    ${OUTPUT_TDEF}  LINEAR  ${OUTPUT_TDEF_START}  1mo/" \
        -e "s/^ -1,40,1 / 99 /" \
        -e "/^CHSUB .*$/d" \
    > ${OUTPUT_CTL}
    rm ${OUTPUT_CTL}.tmp1

    #=====================================#
    #      month loop (for each file)     #
    #=====================================#
    YEAR=$(  echo ${START_DATE} | cut -b 1-4 )
    MONTH=$( echo ${START_DATE} | cut -b 5-6 )
    YEARPP=-1
    MONTHPP=-1
    #echo ${YEAR} ${MONTH}
    #VARS_MON=( $( expand_vars ${#VARS_MON[@]} ${VARS_MON[@]} ) )
    TNOW=-1
    while [ 1 = 1 ] ; do
	if [ ${YEARPP} -ne -1 ] ; then
	    YEAR=${YEARPP}
	    MONTH=${MONTHPP}
	fi
	MONTHPP=$( expr ${MONTH} + 1 ) || exit 1
	YEARPP=${YEAR}
	if [ ${MONTHPP} = 13 ] ; then
	    MONTHPP=1
	    YEARPP=$( expr ${YEARPP} + 1 ) || exit 1
	fi
	MONTHPP=$( printf "%02d" ${MONTHPP} )
	[ ${YEARPP}${MONTHPP}01 -gt ${ENDPP_DATE} ] && break
        #
	echo ${YEAR}${MONTH}
	#
        #----- output data -----#
	#
        # File name convention
        #   ms_tem_20040601.grd  (center of the date if incre > 1dy)
	#
        # output file exist?
	for(( e=1; ${e}<=${EDEF}; e=${e}+1 )) ; do
            STR_ENS=""
	    if [ ${EDEF} -gt 1 ] ; then
		STR_ENS=${e}
		[ ${e} -lt 100 ] && STR_ENS="0${STR_ENS}"
		[ ${e} -lt 10  ] && STR_ENS="0${STR_ENS}"
		STR_ENS="_bin${STR_ENS}"
	    fi
	    #
	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_${YEAR}${MONTH}${STR_ENS}.grd
	    #
	    [ ! -d ${OUTPUT_DIR}/${VAR} ] && mkdir -p ${OUTPUT_DIR}/${VAR}
	    if [ -f ${OUTPUT_DATA} ] ; then
		SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' )
		SIZE_OUT_EXACT=$( echo "4*${XDEF}*${YDEF}*${ZDEF}*${VDEF}" | bc )
		if [ ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} \
		    -a "${OVERWRITE}" != "yes" \
		    -a "${OVERWRITE}" != "dry-rm" \
		    -a "${OVERWRITE}" != "rm" ] ; then
		    continue 2
		fi
		echo "Removing ${OUTPUT_DATA}"
		echo ""

exit 1
		[ "${OVERWRITE}" = "dry-rm" ] && continue 1
		rm -f ${OUTPUT_DATA}
	    fi
	done
	[ "${OVERWRITE}" = "rm" -o "${OVERWRITE}" = "dry-rm" ] && continue 1

	NOTHING=0

	TMIN=-1
	TMAX=-1
	if [ ${TNOW} -eq -1 ] ; then
	    TNOW_START=1
	    TNOW=0
	    TIME=$( date -u --date "${TDEF_START} ${TDEF_INCRE_SEC} seconds ago" +%H:%Mz%d%b%Y )
	else
	    TNOW_START=${TNOW}
	    let TNOW=TNOW-1
	    TIME=$( date -u --date "${TIME} ${TDEF_INCRE_SEC} seconds ago" +%H:%Mz%d%b%Y )
	fi
	    
#	for(( i=1; $i<=${TDEF}; i=$i+1 )) ; do
	for(( i=${TNOW_START}; $i<=${TDEF}; i=$i+1 )) ; do
	    let TNOW=TNOW+1
	    TIME=$( date -u --date "${TIME} ${TDEF_INCRE_SEC} seconds" +%H:%Mz%d%b%Y )
#	    echo "i=${i} ${TNOW} ${TIME}"

	    YYYYMM=$( date -u --date "${TIME}" +%Y%m )
	    DD=$( date -u --date "${TIME}" +%d )
	    HHMM=$( date -u --date "${TIME}" +%H:%M )
	    if [ "${DD}" = "01" -a ${TMIN} -eq -1 -a "${YYYYMM}" = "${YEAR}${MONTH}" ] ; then
		if [ "${HHMM}" = "00:00" ] ; then
		    TMIN=$( expr ${i} + 1 )
		else
		    TMIN=${i}
		fi
	    elif [ ${TMIN} -ne -1 -a ${TMAX} -eq -1 -a "${YYYYMM}" != "${YEAR}${MONTH}" ] ; then
		if [ "${HHMM}" = "00:00" ] ; then
		    TMAX=${i}
		else
		    TMAX=$( expr ${i} - 1 )
		fi
		break
	    fi
	done

	if [ ${TMIN} -gt 0 -a ${TMAX} -le 0 ] ; then
	    TIMEPP=$( date -u --date "${TIME} ${TDEF_INCRE_SEC} seconds" +%H:%Mz%d%b%Y )
	    YYYYMMPP=$( date -u --date "${TIMEPP}" +%Y%m )
	    if [ "${YYYYMMPP}" != "${YEAR}${MONTH}" ] ; then
		TMAX=${TDEF}
	    fi
	fi

	if [ ${TMIN} -le 0 -o ${TMAX} -le 0 ] ; then
	    echo "warning: TMIN=${TMIN} and TMAX=${TMAX}"
	    echo "skipped!"
	    continue
	fi

	cd ${TEMP_DIR}
	for(( e=1; ${e}<=${EDEF}; e=${e}+1 )) ; do
	    STR_ENS=""
	    TEMPLATE_ENS=""
	    if [ ${EDEF} -gt 1 ] ; then
		STR_ENS=${e}
		[ ${e} -lt 100 ] && STR_ENS="0${STR_ENS}"
		[ ${e} -lt 10  ] && STR_ENS="0${STR_ENS}"
		STR_ENS="_bin${STR_ENS}"
		TEMPLATE_ENS="_bin%e"
	    fi
	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_${YEAR}${MONTH}${STR_ENS}.grd

	    rm -f temp.grd temp2.grd
	    for SUBVAR in ${SUBVARS[@]} ; do
		cat > temp.gs <<EOF
'reinit'
'xopen ../${INPUT_CTL}'
'set gxout fwrite'
'set fwrite -be temp2.grd'
'set undef -0.99900E+35'
'set x 1 ${XDEF}'
'set y 1 ${YDEF}'
'set e ${e}'
z = 1
while( z <= ${ZDEF} )
  say '  z = ' % z
  'set z 'z
  say '    d ave(${SUBVAR},t=${TMIN},t=${TMAX})'
  'd ave(${SUBVAR},t=${TMIN},t=${TMAX})'
  z = z + 1
endwhile
'disable fwrite'
'quit'
EOF
		${GRADS_CMD} -blc temp.gs || exit 1 #> grads.log
		cat temp2.grd >> temp.grd
		rm temp2.grd
	    done
	    mv temp.grd ../${OUTPUT_DATA}
	    rm temp.gs

	done

	cd - > /dev/null

    done
done

if [ ${NOTHING} -eq 1 ] ; then
    echo "info: nothing to do"
fi

echo "$0 normally finished"
