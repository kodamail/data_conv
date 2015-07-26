#!/bin/sh
# w, rho -> omega [Pa/s]
#
# TODO: extend to stability, baroclinicity, etc for low-res data
#
. ./common.sh     || exit 1
#. ./usr/common.sh || exit 1

echo "########## $0 start ##########"
set -x
START_DATE=$1    # date (YYYYMMDD)
ENDPP_DATE=$2    # date (YYYYMMDD)
INOUT_DIR=$3
PDEF_LEVELS=$4
VAR_W=$5
VAR_RHO=$6     # = "none" if not specified
VAR_TEM=$7     # optional, = "none" if not specified
OVERWRITE=$8   # optional
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

PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1

TYPE=${VAR_W:1:1}  # snapshot or average

NOTHING=1
#=====================================#
#      var = ms_omega                 #
#=====================================#
for VAR in m${TYPE}_omega ; do
    #
    # check output dir
    #
    if [ -f "${INOUT_DIR}/${VAR}/_locked" ] ; then
	echo "info: ${INOUT_DIR} is locked"
	continue
    fi
    #
    # check input data
    #
    INPUT_W_CTL=${INOUT_DIR}/${VAR_W}/${VAR_W}.ctl
    if [ "${VAR_RHO}" != "none" ] ; then
	INPUT_RHO_CTL=${INOUT_DIR}/${VAR_RHO}/${VAR_RHO}.ctl
	INPUT_TEM_CTL=""
    else
	INPUT_RHO_CTL=""
	INPUT_TEM_CTL=${INOUT_DIR}/${VAR_TEM}/${VAR_TEM}.ctl
    fi
    for CTL in ${INPUT_RHO_CTL} ${INPUT_TEM_CTL} ${INPUT_W_CTL} ; do  # w must be evaluated last!
	if [ ! -f ${CTL} ] ; then
	    echo "warning: ${CTL} does not exist"
	    continue 2
	fi
	FLAG=( $( exist_data.sh \
	    ${CTL} \
	    $( time_2_grads ${START_DATE} ) \
	    $( time_2_grads ${ENDPP_DATE} ) \
	    "MMPP" ) )
	if [ "${FLAG[0]}" != "ok" ] ; then
	    echo "warning: All or part of data does not exist (CTL=${CTL})"
	    continue 2
	fi
    done
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
    DIMS=( $( ${BIN_GRADS_CTL} ${INPUT_W_CTL} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]} ; TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    TDEF_START=$(     ${BIN_GRADS_CTL} ${INPUT_W_CTL} TDEF 1 ) || exit 1
    TDEF_INCRE_SEC=$( ${BIN_GRADS_CTL} ${INPUT_W_CTL} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
    TDEF_INCRE_MN=$(  ${BIN_GRADS_CTL} ${INPUT_W_CTL} TDEF INC --unit MN  | sed -e "s/MN//"  ) || exit 1
#    XDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_W_CTL} ${OPT_NC} key=XDEF target=NUM )
#    YDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_W_CTL} ${OPT_NC} key=YDEF target=NUM )
#    ZDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_W_CTL} ${OPT_NC} key=ZDEF target=NUM )
#    EDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_W_CTL} ${OPT_NC} key=EDEF target=NUM )
#    TDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_W_CTL} ${OPT_NC} key=TDEF target=NUM )
#    TDEF_START=$( ${BIN_GRADS_CTL} ctl=${INPUT_W_CTL} ${OPT_NC} key=TDEF target=1 )
#    TDEF_INCRE_SEC=$( grads_ctl.pl ctl=${INPUT_W_CTL} ${OPT_NC} key=TDEF target=STEP unit=SEC | sed -e "s/SEC//" )
#    TDEF_INCRE_MN=$( grads_ctl.pl ctl=${INPUT_W_CTL} ${OPT_NC} key=TDEF target=STEP unit=MN | sed -e "s/MN//" )

    OUTPUT_TDEF_ONEFILE=$( echo "60 * 60 * 24 / ${TDEF_INCRE_SEC}" | bc )   # per one file
    OUTPUT_CTL=${INOUT_DIR}/${VAR}/${VAR}.ctl
    [ ! -d ${INOUT_DIR}/${VAR}     ] && mkdir -p ${INOUT_DIR}/${VAR}
#    [ ! -d ${INOUT_DIR}/${VAR}/log ] && mkdir -p ${INOUT_DIR}/${VAR}/log
    #
    # generate control file (unified)
    #
    if [ "${EXT}" = "nc" ] ; then
	${BIN_NC2CTL} ${INPUT_NC_1} ${OUTPUT_CTL}.tmp1
    else
	cp ${INPUT_W_CTL} ${OUTPUT_CTL}.tmp1
    fi
    #
    OUTPUT_CTL=${INOUT_DIR}/${VAR}/${VAR}.ctl
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
    PDEF_LIST=$( echo ${PDEF_LEVELS} | sed -e "s/,/ /"g )
    sed ${OUTPUT_CTL}.tmp1 \
        -e "s/^DSET .*$/DSET \^${VAR}_%ch.grd/" \
	-e "/^CHSUB .*/d"  \
	-e "s/TEMPLATE//ig" \
        -e "s/^OPTIONS /OPTIONS TEMPLATE /i" \
	-e "s/^UNDEF .*$/UNDEF -0.99900E+35/i"  \
	-e "/^ZDEF/,/^TDEF/{" \
	-e "/^\(ZDEF\|TDEF\)/!D" \
	-e "}" \
	-e "s/^ZDEF .*/ZDEF  ${PDEF}  LEVELS  ${PDEF_LIST}/" \
        -e "s/^TDEF .*$/TDEF    ${TDEF}  LINEAR  ${TDEF_START}  ${TDEF_INCRE_MN}mn/" \
	-e "s/^${VAR_W} /${VAR} /" \
	| sed -e "s/m\/s/Pa\/s/" \
	> ${OUTPUT_CTL}.tmp
    sed -e "/^DSET/q" ${OUTPUT_CTL}.tmp   > ${OUTPUT_CTL}
    cat ${OUTPUT_CTL}.chsub               >> ${OUTPUT_CTL}
    sed -e "0,/^DSET/d" ${OUTPUT_CTL}.tmp >> ${OUTPUT_CTL}
    rm ${OUTPUT_CTL}.tmp ${OUTPUT_CTL}.tmp1 ${OUTPUT_CTL}.chsub

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
        #
        #----- set date for ${DATE} -----#
        #
	YEAR=${DATE:0:4}
        MONTH=${DATE:4:2}
        DAY=${DATE:6:2}
        #
	TMIN=${d}
	TMAX=$( echo "${d}+${OUTPUT_TDEF_ONEFILE}-1" | bc )
	#
        #----- output data -----#
	#
        # File name convention
        #   ms_tem_20040601.grd  (center of the date if incre > 1dy)
	#
	OUTPUT_DATA=${INOUT_DIR}/${VAR}/${VAR}_${YEAR}${MONTH}${DAY}.grd
	#
        # output file exist?
	if [ -f ${OUTPUT_DATA} ] ; then
	    SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' )
	    SIZE_OUT_EXACT=$( echo 4*${XDEF}*${YDEF}*${PDEF}*${OUTPUT_TDEF_ONEFILE} | bc )
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
	[ "${OVERWRITE}" = "rm" -o "${OVERWRITE}" = "dry-rm" ] && continue 1
	
	NOTHING=0
	#
	# (w, rho) or (w, tem) -> omega
	#
	cat > ${TEMP_DIR}/temp.gs <<EOF
'reinit'
EOF
	GRAV=9.80616  # following NICAM
	GASR=287.04   # following NICAM
	if [ "${INPUT_RHO_CTL}" != "" ] ; then
	    VAR_GRADS="(-${VAR_W}.1*${VAR_RHO}.2*${GRAV})"
	    cat >> ${TEMP_DIR}/temp.gs <<EOF
'xopen ${INPUT_W_CTL}'
'xopen ${INPUT_RHO_CTL}'
EOF
	else
	    VAR_GRADS="(-${VAR_W}.1*(lev*100)*${GRAV}/(${GASR}*${VAR_TEM}.2))"
	    cat >> ${TEMP_DIR}/temp.gs <<EOF
'xopen ${INPUT_W_CTL}'
'xopen ${INPUT_TEM_CTL}'
EOF
	fi

	cat >> ${TEMP_DIR}/temp.gs <<EOF
*'set gxout grfill'
'set gxout fwrite'
'set undef dfile'
'set fwrite -be ${OUTPUT_DATA}'

'set x 1 '${XDEF}
'set y 1 '${YDEF}

t = ${TMIN}
while( t <= ${TMAX} )
  'set t 't
*  say 't=' % t
  z = 1
  while( z <= ${ZDEF} )
    'set z 'z
*    say '  z=' % z

    'd ${VAR_GRADS}'

    z = z + 1
  endwhile
  t = t + 1
endwhile

'disable fwrite'
'quit'
EOF
	grads -blc ${TEMP_DIR}/temp.gs 
	rm -f ${TEMP_DIR}/temp.gs

    done   # date loop

done

if [ ${NOTHING} -eq 1 ] ; then
    echo "info: nothing to do"
fi

