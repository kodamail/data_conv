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
XYDEF=$5
OVERWRITE=$6   # optional
TARGET_VAR=$7  # optional
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
#      var loop                       #
#=====================================#
for VAR in ${VAR_LIST[@]} ; do
    #
    # check output dir
    #
    if [ -f "${OUTPUT_DIR}/${VAR}/_locked" ] ; then
	echo "info: ${OUTPUT_DIR} is locked"
	#echo "##########"
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
	"PP" ) )
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
    XDEF=$( grads_ctl.pl ctl=${INPUT_CTL} ${OPT_NC} key=XDEF target=NUM )
    YDEF=$( grads_ctl.pl ctl=${INPUT_CTL} ${OPT_NC} key=YDEF target=NUM )
    ZDEF=$( grads_ctl.pl ctl=${INPUT_CTL} ${OPT_NC} key=ZDEF target=NUM )
    #EDEF=$( grads_ctl.pl ctl=${INPUT_CTL} ${OPT_NC} key=EDEF target=NUM )
    TDEF=$( grads_ctl.pl ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=NUM )
    TDEF_START=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=1 )
    #TDEF_START=$( grep -i "^TDEF" ${INPUT_CTL} | awk '{ print $4 }' )
    TDEF_INCRE_SEC=$( grads_ctl.pl ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=STEP unit=SEC | sed -e "s/SEC//" )
    TDEF_INCRE_MN=$(  grads_ctl.pl ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=STEP unit=MN | sed -e "s/MN//" )

    #
    XDEF_OUT=$( echo ${XYDEF} | cut -d x -f 1 )
    YDEF_OUT=$( echo ${XYDEF} | cut -d x -f 2 )
    OUTPUT_TDEF_ONEFILE=$( echo "60 * 60 * 24 / ${TDEF_INCRE_SEC}" | bc )   # per one file
    #OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_${TID}.grd
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
    [ ! -d ${OUTPUT_DIR}/${VAR}     ] && mkdir -p ${OUTPUT_DIR}/${VAR}
    [ ! -d ${OUTPUT_DIR}/${VAR}/log ] && mkdir -p ${OUTPUT_DIR}/${VAR}/log
    #
    # generate control file (unified)
    #
    if [ "${EXT}" = "nc" ] ; then
	${BIN_NC2CTL} ${INPUT_NC_1} ${OUTPUT_CTL}.tmp1
    else
	cp ${INPUT_CTL} ${OUTPUT_CTL}.tmp1
    fi
    #
    [ ! -d ${OUTPUT_DIR}/${VAR} ] && mkdir -p ${OUTPUT_DIR}/${VAR}
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
    #
    XDEF_OUT_START=$( echo "scale=7; 360 / ${XDEF_OUT} / 2" | bc )
    XDEF_OUT_INT=$(   echo "scale=7; 360.0 / ${XDEF_OUT}" | bc )
    YDEF_OUT_START=$( echo "scale=7; -90 + 180 / ${YDEF_OUT} / 2" | bc )
    YDEF_OUT_INT=$(   echo "scale=7; 180.0 / ${YDEF_OUT}" | bc )
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

    sed ${OUTPUT_CTL}.tmp1 \
        -e "s/^DSET .*$/DSET \^${VAR}_%ch.grd/" \
	-e "/^CHSUB .*/d"  \
        -e "s/^OPTIONS /OPTIONS TEMPLATE /i" \
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
    rm ${OUTPUT_CTL}.tmp ${OUTPUT_CTL}.chsub
#   cat ${OUTPUT_CTL}

    #=====================================#
    #      date loop (for each file)      #
    #=====================================#
    TMP_SEC_MIN=$(  date -u --date "00:00z${START_DATE}" +%s )  # TODO: ->dev
    TMP_SEC_MAX=$(  date -u --date "00:00z${ENDPP_DATE}" +%s )  # TODO: ->dev
    DATE_SEC=$( date -u --date "${TDEF_START}" +%s )
    dmin=$( echo "( ${TMP_SEC_MIN} - ${DATE_SEC} ) / ${TDEF_INCRE_SEC} - 1" | bc )
    dmin=$( echo "( ${dmin} / ${OUTPUT_TDEF_ONEFILE} ) * ${OUTPUT_TDEF_ONEFILE} + 1" | bc )
    [ ${dmin} -lt 1 ] && dmin=1
    TMP=$( echo "${TDEF_INCRE_SEC} * ( $dmin - 1 )" | bc )
    DATE_GRADS=$( date -u --date "${TDEF_START} ${TMP} seconds" +%H:%Mz%d%b%Y )

    dmax=$( echo "( ${TMP_SEC_MAX} - ${DATE_SEC} ) / ${TDEF_INCRE_SEC} + ${OUTPUT_TDEF_ONEFILE} + 1" | bc )

#    for(( d=1; ${d}<=${TDEF}; d=${d}+${OUTPUT_TDEF_ONEFILE} )) ; do
    for(( d=$dmin; ${d}<=${dmax}; d=${d}+${OUTPUT_TDEF_ONEFILE} )) ; do

#	if [ ${d} -eq 1 ] ; then
#	    DATE_GRADS=${TDEF_START}
#	else
	if [ ${d} -gt ${dmin} ] ; then
	    #DATE_GRADS=$( date -u --date "${DATE_GRADS} 1 days" +%H:%Mz%d%b%Y )
	    for(( dd=1; ${dd}<=${OUTPUT_TDEF_ONEFILE}; dd=${dd}+1 )) ; do
		DATE_GRADS=$( date -u --date "${DATE_GRADS} ${TDEF_INCRE_SEC} seconds" +%H:%Mz%d%b%Y )
	    done
	fi
	DATE=$(     date -u --date "${DATE_GRADS}" +%Y%m%d )
	DATE_SEC=$( date -u --date "${DATE_GRADS}" +%s )
#	TMP_SEC_MIN=$(  date -u --date "00:00z${START_DATE}" +%s )
#	TMP_SEC_MAX=$(  date -u --date "00:00z${ENDPP_DATE}" +%s )
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
#	echo "${TMIN} ${TMAX}"
	#
        #----- output data -----#
	#
        #
        # File name convention
        #   ms_tem_20040601.grd  (center of the date if incre > 1dy)
	#
	OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_${YEAR}${MONTH}${DAY}.grd
	#
        # output file exist?
	if [ -f ${OUTPUT_DATA} ] ; then
	    SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' )
	    SIZE_OUT_EXACT=$( echo 4*${XDEF_OUT}*${YDEF_OUT}*${ZDEF}*${OUTPUT_TDEF_ONEFILE} | bc )
	    if [   ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} \
		-a "${OVERWRITE}" != "yes" \
		-a "${OVERWRITE}" != "dry-rm" \
		-a "${OVERWRITE}" != "rm" ] ; then
#		echo "  -> info: nothing to do"
#		echo "##########"
		continue 1
	    fi
	    echo "Removing ${OUTPUT_DATA}"
	    echo ""
	    #echo ${SIZE_OUT} ${SIZE_OUT_EXACT}
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
	#
        # assuming globally uniform grid
	#
	cd ${TEMP_DIR}
#	cat > roughen.cnf <<EOF
#&ROUGHEN_PARAM
#    imax    = ${XDEF},      ! grid number for x-axis (original data)
#    jmax    = ${YDEF},      ! grid number for y-axis (original data)
#    imax2   = ${XDEF_OUT},  ! grid number for x-axis (output data)
#    jmax2   = ${YDEF_OUT},  ! grid number for y-axis (output data)
#    kmax    = ${ZDEF},      ! vertical grid number
#    tmax    = ${OUTPUT_TDEF_ONEFILE},      ! time
#    varmax  = 1,            ! variable number
#    undef   = -99.9e+33,
#    varname = '${VAR}',
#    indir = './'    ! input directory name
#    insuffix = '_${DATE}.grd.in'            ! suffix of original data
#    outdir = '.'                        ! output directory name
#    outsuffix = '_${DATE}.grd'           ! suffix of output data
#/
#EOF
	# for 2013/04/18 or later NICAM
	cat > roughen.cnf <<EOF
&ROUGHEN_PARAM
    indir         = './',               ! input directory name
    insuffix      = '_${DATE}.grd.in',  ! suffix of original data
    input_netcdf  = .false.,
    imax_in       = ${XDEF},            ! grid number for x-axis (original data)
    jmax_in       = ${YDEF},            ! grid number for y-axis (original data)

    outdir        = '.',                ! output directory name
    outsuffix     = '_${DATE}.grd',     ! suffix of output data
    output_netcdf = .false.,
    imax_out      = ${XDEF_OUT},        ! grid number for x-axis (output data)
    jmax_out      = ${YDEF_OUT},        ! grid number for y-axis (output data)

    kmax          = ${ZDEF},            ! vertical grid number
    tmax          = ${OUTPUT_TDEF_ONEFILE}, ! time
    varmax        = 1,                  ! variable number
    varname       = '${VAR}',
    undef         = -99.9e+33,
EOF

	# if YDEF is odd  -> [-90:90]
	# if YDEF is even -> [-8_:8_] (default in roughen)
	let YDEF_OUT_TMP=YDEF_OUT/2*2
	if [ ${YDEF_OUT} -ne ${YDEF_OUT_TMP} ] ; then
	    cat >> roughen.cnf <<EOF
    latmin_out = -90.0
    latmax_out = 90.0
EOF
	fi
	cat >> roughen.cnf <<EOF
/
EOF
	

        ${BIN_ROUGHEN} || exit 1
#    mv roughen.cnf ${VAR}_output_${DAYS}dy.grd ../${OUTPUT_DIR}/${VAR}
	mv ${VAR}_${DATE}.grd ../${OUTPUT_DIR}/${VAR}
	mv roughen.cnf       ../${OUTPUT_DIR}/${VAR}/log/roughen_${DATE}.cnf
	rm ${VAR}_${DATE}.grd.in

	cd - > /dev/null

    done   # date loop

done  # var loop


if [ ${NOTHING} -eq 1 ] ; then
    echo "info: nothing to do"
#    echo "##########"
fi

echo "$0 normally finished"
