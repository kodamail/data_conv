#!/bin/sh
# NOTE: 02/29 is not considered in the calculation
export LANG=en

START_DATE=$1    # date (YYYYMMDD)
ENDPP_DATE=$2    # date (YYYYMMDD)
INPUT_DIR=$3
OUTPUT_DIR=$4
OVERWRITE=$5   # optional
TARGET_VAR=$6   # optional

echo "########## daily_clim.sh start ##########"
echo "1: $1"
echo "2: $2"
echo "3: $3"
echo "4: $4"
echo "5: $5"
echo "6: $6"
echo "##########"

. common.sh 
create_temp
trap "finish daily_clim.sh" 0

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


#START_DATE=19780601
#ENDPP_DATE=19800701
# -> NUM_YEAR=2

#../sl/144x72/clim_1dy_mean/19780601_19800531/sa_tppn/

NUM_YEAR=0
YMD=${START_DATE}
while [ ${YMD} -le ${ENDPP_DATE} ] ; do
    YMD=$( date -u --date "${YMD} 1 years" +%Y%m%d )
    let NUM_YEAR++
done
let NUM_YEAR--
END_DATE=$( date -u --date "${START_DATE} ${NUM_YEAR} years -1 days" +%Y%m%d )
END_DATE_1YR=$( date -u --date "${START_DATE} 1 years -1 days" +%Y%m%d )

OUTPUT_DIR=${OUTPUT_DIR}/${START_DATE}_${END_DATE}
echo "output dir = ${OUTPUT_DIR}"


NOTHING=1
#=====================================#
#            variable loop            #
#=====================================#
for VAR in ${VAR_LIST[@]} ; do
    echo "VAR = ${VAR}"
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
    TYPE=$( echo ${VAR} | cut -b 2 )      # snapshot or average
    VAR_PRES=m${TYPE}_pres
    if [ ! -f ${INPUT_CTL} ] ; then
	echo "warning: ${INPUT_CTL} does not exist"
	continue
    fi
    FLAG=( $( exist_data.sh \
	${INPUT_CTL} \
	$( time_2_grads ${START_DATE} ) \
	$( time_2_grads ${ENDPP_DATE} ) \
	"MMPP" ) )
    if [ "${FLAG[0]}" != "ok" ] ; then
	echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})"
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
    XDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=XDEF target=NUM )
    YDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=YDEF target=NUM )
    ZDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=ZDEF target=NUM )
    EDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=EDEF target=NUM )
    SUBVARS=( $( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=VAR_LIST ) )
    VDEF=${#SUBVARS[@]}
    TDEF_INCRE_SEC=$( grads_ctl.pl ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=STEP unit=SEC | sed -e "s/SEC//" )
    if [ ${TDEF_INCRE_SEC} -ne 86400 ] ; then
	echo "warning: ${INPUT_CTL} is not a daily data"
	echo ${TDEF_INCRE_SEC}
	continue
    fi
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
    TDEF_END=${TIME}
    sed ${OUTPUT_CTL}.tmp1 \
        -e "s/^DSET .*$/DSET ^${VAR}_%m2%d2${STR_ENS}.grd/" \
	-e "s/TEMPLATE//ig" \
        -e "s/^OPTIONS /OPTIONS TEMPLATE 365_DAY_CALENDAR /i" \
        -e "/^OPTIONS yrev$/id" \
        -e "s/ yrev//i" \
	-e "s/^UNDEF .*$/UNDEF -0.99900E+35/i"  \
        -e "s/^TDEF .*$/TDEF    3650 LINEAR  12z01jan2000  1dy/" \
        -e "s/^ -1,40,1 / 99 /" \
        -e "/^CHSUB .*$/d" \
    > ${OUTPUT_CTL}
    rm ${OUTPUT_CTL}.tmp1

    #=====================================#
    #       day loop (for each file)      #
    #=====================================#
    YMD=${START_DATE}
    while [ ${YMD} -le ${END_DATE_1YR} ] ; do
	if [ "${YMD:4:4}" = "0229" ] ; then
	    YMD=$( date -u --date "${YMD} 1 days" +%Y%m%d )
	    continue
	fi
	echo "  YMD = ${YMD}"
	YEAR=${YMD:0:4}
	MONTH=${YMD:4:2}
	DAY=${YMD:6:2}
#	GRADS_DATE=$( date -u --date "${YMD}" +%d%b )%y
	GRADS_DATE=12z$( date -u --date "${YMD}" +%d%b )%y
	let YEAR_END=YEAR+NUM_YEAR-1

	for(( e=1; ${e}<=${EDEF}; e=${e}+1 )) ; do
            STR_ENS=""
	    if [ ${EDEF} -gt 1 ] ; then
		STR_ENS=${e}
		[ ${e} -lt 100 ] && STR_ENS="0${STR_ENS}"
		[ ${e} -lt 10  ] && STR_ENS="0${STR_ENS}"
		STR_ENS="_bin${STR_ENS}"
	    fi
	    #
	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_${MONTH}${DAY}${STR_ENS}.grd
	    #
	    [ ! -d ${OUTPUT_DIR}/${VAR} ] && mkdir -p ${OUTPUT_DIR}/${VAR}
	    if [ -f ${OUTPUT_DATA} ] ; then
		SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' )
		SIZE_OUT_EXACT=$( echo "4*${XDEF}*${YDEF}*${ZDEF}*${VDEF}" | bc )
		if [ ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} \
		    -a "${OVERWRITE}" != "yes" \
		    -a "${OVERWRITE}" != "dry-rm" \
		    -a "${OVERWRITE}" != "rm" ] ; then
		    YMD=$( date -u --date "${YMD} 1 days" +%Y%m%d )
		    continue 2
		fi
		echo "Removing ${OUTPUT_DATA}"
		echo ""
		[ "${OVERWRITE}" = "dry-rm" ] && continue 1
		rm -f ${OUTPUT_DATA}
	    fi
	done
	[ "${OVERWRITE}" = "rm" -o "${OVERWRITE}" = "dry-rm" ] && continue 1

	NOTHING=0

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
	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_${MONTH}${DAY}${STR_ENS}.grd


	    cat > temp.gs <<EOF
'reinit'
'xopen ../${INPUT_CTL}'
rc = gsfallow("on")
'set gxout fwrite'
'set fwrite -be temp.grd'
'set undef dfile'
'set x 1 ${XDEF}'
'set y 1 ${YDEF}'
EOF

	    for SUBVAR in ${SUBVARS[@]} ; do
		cat >> temp.gs <<EOF
z = 1
while( z <= ${ZDEF} )
  say '  z = ' % z
  'set z 'z
  'clave ${SUBVAR} ${GRADS_DATE} ${GRADS_DATE} ${YEAR} ${YEAR_END}'
  z = z + 1
endwhile
EOF
	    done

	    cat >> temp.gs <<EOF
'disable fwrite'
'quit'
EOF

	    ${GRADS_CMD} -blc temp.gs || exit 1 #> grads.log

	    mv temp.grd ../${OUTPUT_DATA}
	    rm temp.gs

	done
	cd - > /dev/null

	YMD=$( date -u --date "${YMD} 1 days" +%Y%m%d )
    done

done

if [ ${NOTHING} -eq 1 ] ; then
    echo "info: nothing to do"
fi

exit
