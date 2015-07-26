#!/bin/sh
# p on z -> z on p
#
export F_UFMTENDIAN="big"
export LANG=en

START_DATE=$1    # date (YYYYMMDD)
ENDPP_DATE=$2    # date (YYYYMMDD)
INPUT_DIR=$3
OUTPUT_DIR=$4
PDEF_LEVELS=$5
VAR_PRES=$6    
OVERWRITE=$7   # optional

#CONF=$1
#TID=$2
#INPUT_DIR=$3
#OUTPUT_DIR=$4
#OVERWRITE=$5

#DAYS=00001-00010
#INPUT_DIR=../ml_zlev/144x72x40/tstep
#OUTPUT_DIR=../ml_plev/144x72x18/tstep
#OVERWRITE="no"

#. ${CONF}

##########################################################

echo "########## plev_z.sh start ##########"
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
trap "finish plev_z.sh" 0

if [   "${OVERWRITE}" != ""       \
    -a "${OVERWRITE}" != "yes"    \
    -a "${OVERWRITE}" != "no"     \
    -a "${OVERWRITE}" != "dry-rm" \
    -a "${OVERWRITE}" != "rm"  ] ; then
    echo "error: OVERWRITE = ${OVERWRITE} is not supported yet"
    exit 1
fi

PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1

NOTHING=1
#=====================================#
#      var = ms_z                     #
#=====================================#
for VAR in ms_z ; do
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
    INPUT_CTL=${INPUT_DIR}/${VAR_PRES}/${VAR_PRES}.ctl
    TYPE=$( echo ${VAR_PRES} | cut -b 2 )      # snapshot or average

    if [ ! -f ${INPUT_CTL} ] ; then
	echo "warning: ${INPUT_CTL} does not exist"
	continue
    fi
    FLAG=( $( exist_data.sh \
	${INPUT_CTL} \
	$( time_2_grads ${START_DATE} ) \
	$( time_2_grads ${ENDPP_DATE} ) \
	"PP" ) )
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
    TDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=NUM )
    TDEF_START=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=1 )
    TDEF_INCRE_SEC=$( grads_ctl.pl ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=STEP unit=SEC | sed -e "s/SEC//" )
    TDEF_INCRE_MN=$( grads_ctl.pl ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=STEP unit=MN | sed -e "s/MN//" )

    OUTPUT_TDEF_ONEFILE=$( echo "60 * 60 * 24 / ${TDEF_INCRE_SEC}" | bc )   # per one file
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
	-e "s/^${VAR_PRES}\( *\)${ZDEF}/${VAR}\1${PDEF}/" \
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
	YEAR=$(  echo ${DATE} | cut -c 1-4 )
	MONTH=$( echo ${DATE} | cut -c 5-6 )
	DAY=$(   echo ${DATE} | cut -c 7-8 )
	#
	TMIN=${d}
	TMAX=$( echo "${d}+${OUTPUT_TDEF_ONEFILE}-1" | bc )
	#
        #----- output data -----#
	#
        # File name convention
        #   ms_tem_20040601.grd  (center of the date if incre > 1dy)
	#
	OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_${YEAR}${MONTH}${DAY}.grd
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
	# create z on z
	#
	mkdir -p ${TEMP_DIR}/ml_zlev
	mkdir -p ${TEMP_DIR}/ml_plev
	GS=${TEMP_DIR}/temp.gs
	rm -f ${GS}
	cat > ${GS} <<EOF
'reinit'
'open ${INPUT_CTL}'
'set gxout fwrite'
'set fwrite -be ${TEMP_DIR}/${VAR}_${DATE}.grd.in'
'set undef dfile'
'set x 1 ${XDEF}'
'set y 1 ${YDEF}'

t = ${TMIN}
while( t <= ${TMAX} )
*  say 't = 't
  'set t 't

  z = 1
  while( z <= ${ZDEF} )
*    say '  z = 'z
    'set z 'z

    'd lev'

    z = z + 1
  endwhile

  t = t + 1
endwhile

'quit'
EOF
	grads -blc ${GS}
	#
        # interpolate z.grd to pressure level
	#
#	sed ${INPUT_CTL} \
#	    -e "s/ms_pres/ms_z/" \
#	    > ${TEMP_DIR}/ml_zlev/${VAR}/${VAR}.ctl
	
        get_data ${INPUT_CTL} ${VAR_PRES} ${TMIN} ${TMAX} \
	    ${TEMP_DIR}/${VAR_PRES}_${DATE}.grd.in || exit 1

#	ls -l ${TEMP_DIR}/ml_zlev/


	cd ${TEMP_DIR}
	cat > z2pre.cnf <<EOF
&Z2PRE_PARAM
    imax = ${XDEF},  ! grid number for x-axis
    jmax = ${YDEF},  ! grid number for y-axis
    kmax = ${ZDEF},  ! vertical grid number (in z coordinate) of original data 
    pmax = ${PDEF},  ! vertical grid number (in pressure coordinate) of output data 
    tmax = ${OUTPUT_TDEF_ONEFILE},  ! 
    varmax    = 1,       ! total variable number 
    undef     = -0.999e+35,
    plevel    = ${PDEF_LEVELS}, 
    indir     = '.',   ! input directory name
    varname   = '${VAR}',
    insuffix  = '_${DATE}.grd.in',           ! suffix of original data
    pname     = '${VAR_PRES}_${DATE}.grd.in',         ! pressure data in z-coordinate
    outdir    = '.',                       ! output directory name
    outsuffix = '_${DATE}.grd',          ! suffix of output data
/
!    insuffix = '_output_${DAYS}dy.grd',     ! suffix of original data
!    outsuffix = '_output_${DAYS}dy.grd',    ! suffix of output data
EOF
	/cwork5/kodama/NICAM_src/NICAM_20110114_linden/z2pre/z2pre || exit 1
	mv ${VAR}_${DATE}.grd ../${OUTPUT_DATA}
	mv z2pre.cnf ../${OUTPUT_DIR}/${VAR}/log/z2pre_${DATE}.cnf
	rm -f ${VAR}_${DATE}.grd.in ${VAR_PRES}_${DATE}.grd.in
	
	cd ..

    done   # date loop

done

if [ ${NOTHING} -eq 1 ] ; then
    echo "info: nothing to do"
fi
