#!/bin/sh
#
export F_UFMTENDIAN="big"
export LANG=en


START_DATE=$1    # date (YYYYMMDD)
ENDPP_DATE=$2    # date (YYYYMMDD)
INPUT_ML_DIR=$3
INPUT_SL_DIR=$4
OUTPUT_DIR=$5
OVERWRITE=$6   # optional
TARGET_VAR=$7  # optional

#DAYS="01-10"
#INPUT_DIR=../ml_plev/320x160/tstep
#OUTPUT_DIR=../ml_plev/zmean160/tstep
#OVERWRITE="yes"
#OVERWRITE="no"

echo "########## vint.sh start ##########"
echo "1: $1"
echo "2: $2"
echo "3: $3"
echo "4: $4"
echo "5: $5"
echo "6: $6"
echo "7: $7"
echo "##########"


. common.sh 
create_temp
trap "finish zonal_mean.sh" 0

if [   "${OVERWRITE}" != ""       \
    -a "${OVERWRITE}" != "yes"    \
    -a "${OVERWRITE}" != "no"     \
    -a "${OVERWRITE}" != "dry-rm" \
    -a "${OVERWRITE}" != "rm"  ] ; then
    echo "error: OVERWRITE = ${OVERWRITE} is not supported yet"
    exit 1
fi


if [ "${TARGET_VAR}" = "" ] ; then
    VAR_LIST=( $( ls ${INPUT_ML_DIR}/ ) )
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
	echo "info: ${OUTPUT_DIR} is locked"
	continue
    fi
    #
    # check input data
    #
    INPUT_CTL=${INPUT_ML_DIR}/${VAR}/${VAR}.ctl
    if [ ! -f ${INPUT_CTL} ] ; then
	echo "warning: ${INPUT_CTL} does not exist"
	#echo "##########"
	continue
    fi
    FLAG=( $( exist_data.sh \
	${INPUT_CTL} \
	$( time_2_grads ${START_DATE} ) \
	$( time_2_grads ${ENDPP_DATE} ) \
	"PP" ) )
    if [ "${FLAG[0]}" != "ok" ] ; then
	echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})"
	#echo "##########" 
	continue
    fi
    #
    # check input data (pres)
    #
    VAR_P=${VAR:0:2}_pres
    INPUT_P_CTL=${INPUT_ML_DIR}/${VAR_P}/${VAR_P}.ctl
    if [ ! -f ${INPUT_P_CTL} ] ; then
	echo "warning: ${INPUT_P_CTL} does not exist"
        #echo "##########"
	continue
    fi
    FLAG=( $( exist_data.sh \
	${INPUT_P_CTL} \
	$( time_2_grads ${START_DATE} ) \
	$( time_2_grads ${ENDPP_DATE} ) \
	"PP" ) )
    if [ "${FLAG[0]}" != "ok" ] ; then
	echo "warning: All or part of data does not exist (CTL=${INPUT_P_CTL})"
        #echo "##########" 
	continue
    fi
    #
    # check input data (ps)
    #
#    VAR_PS=s${VAR:1:1}_ps
    VAR_PS=sl_ps
    INPUT_PS_CTL=${INPUT_SL_DIR}/${VAR_PS}/${VAR_PS}.ctl
    if [ ! -f ${INPUT_PS_CTL} ] ; then
	echo "warning: ${INPUT_PS_CTL} does not exist"
        #echo "##########"
	continue
    fi
    FLAG=( $( exist_data.sh \
	${INPUT_PS_CTL} \
	$( time_2_grads ${START_DATE} ) \
	$( time_2_grads ${ENDPP_DATE} ) \
	"PP" ) )
    if [ "${FLAG[0]}" != "ok" ] ; then
	echo "warning: All or part of data does not exist (CTL=${INPUT_PS_CTL})"
        #echo "##########" 
	continue
    fi
    #
    # get number of grid
    #
    XDEF=$( grads_ctl.pl ctl=${INPUT_CTL} key=XDEF target=NUM )
    YDEF=$( grads_ctl.pl ctl=${INPUT_CTL} key=YDEF target=NUM )
    ZDEF=$( grads_ctl.pl ctl=${INPUT_CTL} key=ZDEF target=NUM )
    TDEF=$( grads_ctl.pl ctl=${INPUT_CTL} key=TDEF target=NUM )
    TDEF_START=$( grep -i "^TDEF" ${INPUT_CTL} | awk '{ print $4 }' )
    TDEF_INCRE_SEC=$( grads_ctl.pl ctl=${INPUT_CTL} key=TDEF target=STEP unit=SEC | sed -e "s/SEC//" )
    #
    OUTPUT_TDEF_ONEFILE=$( echo "60 * 60 * 24 / ${TDEF_INCRE_SEC}" | bc )   # per one file


    #
    VAR_OUT=sl_vint_${VAR:3}
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR_OUT}/${VAR_OUT}.ctl
    [ ! -d ${OUTPUT_DIR}/${VAR_OUT}     ] && mkdir -p ${OUTPUT_DIR}/${VAR_OUT}
    [ ! -d ${OUTPUT_DIR}/${VAR_OUT}/log ] && mkdir -p ${OUTPUT_DIR}/${VAR_OUT}/log
    #
    # generate control file (unified)
    #
    [ ! -d ${OUTPUT_DIR}/${VAR_OUT} ] && mkdir -p ${OUTPUT_DIR}/${VAR_OUT}
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR_OUT}/${VAR_OUT}.ctl
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
	DATE=$( date -u --date "${DATE_GRADS}" +%Y%m%d )
	echo "CHSUB  ${CHSUB_MIN}  ${CHSUB_MAX}  ${DATE}" >> ${OUTPUT_CTL}.chsub
    done
    sed ${INPUT_CTL} \
        -e "s/^DSET .*$/DSET \^${VAR_OUT}_%ch.grd/" \
	-e "/^CHSUB .*/d"  \
        -e "/^ZDEF/,/^TDEF/{" \
        -e "/^\(ZDEF\|TDEF\)/!D" \
        -e "}" \
        -e "s/^ZDEF.*/ZDEF  1  LINEAR 1 1/" \
	-e "s/^${VAR} \+${ZDEF}/${VAR_OUT}    1/" \
	> ${OUTPUT_CTL}.tmp
    sed -e "/^DSET/q" ${OUTPUT_CTL}.tmp   > ${OUTPUT_CTL}
    cat ${OUTPUT_CTL}.chsub               >> ${OUTPUT_CTL}
    sed -e "0,/^DSET/d" ${OUTPUT_CTL}.tmp >> ${OUTPUT_CTL}
    rm ${OUTPUT_CTL}.tmp ${OUTPUT_CTL}.chsub

#    cat ${OUTPUT_CTL}

    #=====================================#
    #      date loop (for each file)      #
    #=====================================#
    for(( d=1; ${d}<=${TDEF}; d=${d}+${OUTPUT_TDEF_ONEFILE} )) ; do
	if [ ${d} -eq 1 ] ; then
	    DATE_GRADS=${TDEF_START}
	else
	    #DATE_GRADS=$( date -u --date "${DATE_GRADS} 1 days" +%H:%Mz%d%b%Y )
	    for(( dd=1; ${dd}<=${OUTPUT_TDEF_ONEFILE}; dd=${dd}+1 )) ; do
		DATE_GRADS=$( date -u --date "${DATE_GRADS} ${TDEF_INCRE_SEC} seconds" +%H:%Mz%d%b%Y )
	    done
	fi
	DATE=$(     date -u --date "${DATE_GRADS}" +%Y%m%d )
	DATE_SEC=$( date -u --date "${DATE_GRADS}" +%s )
	TMP_SEC_MIN=$(  date -u --date "00:00z${START_DATE}" +%s )
	TMP_SEC_MAX=$(  date -u --date "00:00z${ENDPP_DATE}" +%s )
	if [ ${TMP_SEC_MIN} -gt ${DATE_SEC} -o ${TMP_SEC_MAX} -lt ${DATE_SEC} ] ; then
	    continue
	fi
	#echo "date=${DATE}"
        #
        #----- set date for ${DATE} -----#
        #
	YEAR=$(  echo ${DATE} | cut -c 1-4 )
	MONTH=$( echo ${DATE} | cut -c 5-6 )
	DAY=$(   echo ${DATE} | cut -c 7-8 )
	#
	TMIN=${d}
	TMAX=$( echo "${d}+${OUTPUT_TDEF_ONEFILE}-1" | bc )
	#echo "${TMIN} ${TMAX}"
	#
        #----- output data -----#
	#
        #
        # File name convention
        #   ms_tem_20040601.grd  (center of the date if incre > 1dy)
	#
	OUTPUT_DATA=${OUTPUT_DIR}/${VAR_OUT}/${VAR_OUT}_${YEAR}${MONTH}${DAY}.grd
	#
        # output file exist?
	if [ -f ${OUTPUT_DATA} ] ; then
	    SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' )
	    SIZE_OUT_EXACT=$( echo 4*1*${XDEF}*${YDEF}*${OUTPUT_TDEF_ONEFILE} | bc )
	    #echo ${SIZE_OUT} ${SIZE_OUT_EXACT}
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

	#
	#----- combine necessary input file -----#
	#
	get_data ${INPUT_CTL} ${VAR} ${TMIN} ${TMAX} \
	    ${TEMP_DIR}/${VAR}_${DATE}.grd.in || exit 1

	get_data ${INPUT_P_CTL} ${VAR_P} ${TMIN} ${TMAX} \
	    ${TEMP_DIR}/${VAR_P}_${DATE}.grd.in || exit 1

	get_data ${INPUT_PS_CTL} ${VAR_PS} ${TMIN} ${TMAX} \
	    ${TEMP_DIR}/${VAR_PS}_${DATE}.grd.in || exit 1

	#
        # vertical integral
	#
	cd ${TEMP_DIR}

	XYDEF=$( echo "${XDEF}*${YDEF}" | bc )

	cat > vint.cnf <<EOF
&VINT_PARAM
    fin_var = '${VAR}_${DATE}.grd.in',
    fout    = '${VAR_OUT}_${DATE}.grd',

    fin_p   = '${VAR_P}_${DATE}.grd.in',
    fin_ps  = '${VAR_PS}_${DATE}.grd.in',
    xydef   = ${XYDEF},
    zdef    = ${ZDEF},
    tdef    = ${OUTPUT_TDEF_ONEFILE},
    undef   = -0.99900E+35,
/

EOF
	vint || exit 1
	mv ${VAR_OUT}_${DATE}.grd ../${OUTPUT_DATA}
	mv vint.cnf ${OUTPUT_DIR}/${VAR_OUT}/log/vint_${DATE}.cnf
	rm -f ${VAR}_${DATE}.grd.in ${VAR_P}_${DATE}.grd.in ${VAR_PS}_${DATE}.grd.in
	cd - > /dev/null
    done

done


if [ ${NOTHING} -eq 1 ] ; then
    echo "info: nothing to do"
#    echo "##########"
fi
