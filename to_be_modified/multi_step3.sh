#!/bin/sh
#
# WARNING: monthly mean is not supported (probably also in future!)
#
export F_UFMTENDIAN="big"
export LANG=en

START_DATE=$1    # date (YYYYMMDD)
ENDPP_DATE=$2    # date (YYYYMMDD)
INPUT_DIR=$3
OUTPUT_DIR=$4
OUTPUT_PERIOD=$5  # e.g. 1dy_mean, 6hr_tstep
OVERWRITE=$6   # optional
TARGET_VAR=$7  # optional
SA=$8          # optional, s:snapshot a:average


#START_DATE=19780601
#ENDPP_DATE=19780701
#INPUT_DIR=../advanced/MIM-0.36r2/zmean_72x18/tstep/sta_tra
#OUTPUT_DIR=../advanced/MIM-0.36r2/zmean_72x18/1dy_mean/sta_tra
#OUTPUT_PERIOD=1dy_mean
#OVERWRITE=yes
#TARGET_VAR=zonal
#SA=s

#INPUT_DIR=../sl/144x72/tstep
#OUTPUT_DIR=./temp
#TARGET_VAR=sa_t2m

echo "########## multi_step3.sh start ##########"
echo "1: $1"
echo "2: $2"
echo "3: $3"
echo "4: $4"
echo "5: $5"
echo "6: $6"
echo "7: $7"
echo "8: $8"
echo "##########"

. common.sh 
create_temp
trap "finish multi_step3.sh" 0

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

BIN_EXIST_DATA=exist_data.sh
#BIN_EXIST_DATA=/cwork5/kodama/program/sh_lib/grads_ctl/dev/exist_data.sh

#
#----- derive parameters -----#
#
# OUTPUT_TYPE
#   tstep : following tstep file name (e.g. sa: mean  ss: snapshot)
#   mean  : always mean
OUTPUT_TYPE=$( echo ${OUTPUT_PERIOD} | cut -d _ -f 2 )  # mean or tstep

# e.g. "5 days", "1 hours"
OUTPUT_TDEF_INCRE_ONEFILE=$( period_2_loop  ${OUTPUT_PERIOD} ) # >= 1 days
OUTPUT_TDEF_INCRE_ONEFILE_SEC=$( echo ${OUTPUT_TDEF_INCRE_ONEFILE} | sed -e "s/ days/\*24\*3600/" -e "s/ hours/\*3600/" | bc )
#
OUTPUT_TDEF_INCRE=$( period_2_incre ${OUTPUT_PERIOD} ) # native
OUTPUT_TDEF_INCRE_SEC=$( echo ${OUTPUT_TDEF_INCRE} | sed -e "s/ days/\*24\*3600/" -e "s/ hours/\*3600/" | bc )
OUTPUT_TDEF_INCRE_GRADS=$( echo "${OUTPUT_TDEF_INCRE}" | sed -e "s/ hours/hr/" -e "s/ days/dy/" )


NOTHING=1
#=====================================#
#            variable loop            #
#=====================================#
for VAR in ${VAR_LIST[@]} ; do
    #echo "VAR = ${VAR}"
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
    FLAG=( $( ${BIN_EXIST_DATA} \
	${INPUT_CTL} \
	$( time_2_grads ${START_DATE} ) \
	$( time_2_grads ${ENDPP_DATE} ) \
	"MMPP" ) )
#	"PP" ) )
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
    # SA
    #   s: snapshot  a: average
    #
    [ "${SA}" = "" ] && SA=${VAR:1:1}
    [ "${SA}" = "l" ] && SA="s"  # temporal
    [ "${OUTPUT_TYPE}" = "mean" ] && SA='a'  # force to specify "mean"
    #
    #----- derive OUTPUT_TDEF_START and OUTPUT_TDEF
    #
    INPUT_CTL=${INPUT_DIR}/${VAR}/${VAR}.ctl
    if [ ! -f ${INPUT_CTL} ] ; then
	echo "warning: ${INPUT_CTL} does not exist"
	echo "##########"
	continue
    fi
    
    INPUT_TDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=NUM )
    INPUT_TDEF_START=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=1 )

    INPUT_TDEF_INCRE_SEC=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=STEP unit=SEC | sed -e "s/SEC//" )
    TSKIP=$( echo "${OUTPUT_TDEF_INCRE_SEC} / ${INPUT_TDEF_INCRE_SEC}" | bc )
    if [ ${TSKIP} -le 1 ] ; then
	echo "Nothing to do!"
	continue
    fi
    #
    if [ "${SA}" = "s" ] ; then
	OUTPUT_TDEF_START=$( date -u --date "${INPUT_TDEF_START}" +%H:%Mz%d%b%Y )
	for(( i=2; $i<=${TSKIP}; i=$i+1 )) ; do
	    OUTPUT_TDEF_START=$( date -u --date "${OUTPUT_TDEF_START} ${INPUT_TDEF_INCRE_SEC} seconds" +%H:%Mz%d%b%Y )
	done
	    
    elif [ "${SA}" = "a" ] ; then
	    
	OUTPUT_TDEF_START=$( date -u --date "${INPUT_TDEF_START}" +%H:%Mz%d%b%Y )
	TEMP=$( echo "${INPUT_TDEF_INCRE_SEC} / 2" | bc )
	for(( i=2; $i<=${TSKIP}; i=$i+1 )) ; do
	    OUTPUT_TDEF_START=$( date -u --date "${OUTPUT_TDEF_START} ${TEMP} seconds" +%H:%Mz%d%b%Y )
	done
    else
	echo "error"
	exit 1
    fi

    OUTPUT_TDEF=$( echo "${INPUT_TDEF} / ${TSKIP}" | bc )
    OUTPUT_TDEF_ONEFILE=$( echo "${OUTPUT_TDEF_INCRE_ONEFILE_SEC} / ${OUTPUT_TDEF_INCRE_SEC}" | bc )   # per one file
    echo "OUTPUT_TDEF_START = ${OUTPUT_TDEF_START}"
    echo "OUTPUT_TDEF       = ${OUTPUT_TDEF}"
    #
    # get number of grid
    #
    XDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=XDEF target=NUM )
    YDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=YDEF target=NUM )
    ZDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=ZDEF target=NUM )
    EDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=EDEF target=NUM )
    SUBVARS=( $( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=VAR_LIST ) )
    VDEF=${#SUBVARS[@]}
    #
    # generate control file (unified)
    #
    [ ! -d ${OUTPUT_DIR}/${VAR}     ] && mkdir -p ${OUTPUT_DIR}/${VAR}
    [ ! -d ${OUTPUT_DIR}/${VAR}/log ] && mkdir -p ${OUTPUT_DIR}/${VAR}/log
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
    #
    rm -f ${OUTPUT_CTL}.chsub
    for(( d=1; ${d}<=${OUTPUT_TDEF}; d=${d}+${OUTPUT_TDEF_ONEFILE} )) ; do
	CHSUB_MIN=${d}
	CHSUB_MAX=$( echo "${d} + ${OUTPUT_TDEF_ONEFILE} - 1" | bc )
	if [ ${d} -eq 1 ] ; then
	    DATE_GRADS=${OUTPUT_TDEF_START}
	else
	    for(( dd=1; ${dd}<=${OUTPUT_TDEF_ONEFILE}; dd=${dd}+1 )) ; do
		DATE_GRADS=$( date -u --date "${DATE_GRADS} ${OUTPUT_TDEF_INCRE_SEC} seconds" +%H:%Mz%d%b%Y )
	    done
	fi
	DATE=$( date -u --date "${DATE_GRADS}" +%Y%m%d )
#	echo "CHSUB  ${CHSUB_MIN}  ${CHSUB_MAX}  ${DATE}" >> ${OUTPUT_CTL}.chsub
	echo "CHSUB  ${CHSUB_MIN}  ${CHSUB_MAX}  ${DATE:0:4}/${DATE}-${DATE}" >> ${OUTPUT_CTL}.chsub
    done

    if [ "${EXT}" = "nc" ] ; then
	${BIN_NC2CTL} ${INPUT_NC_1} ${OUTPUT_CTL}.tmp1
    else
	cp ${INPUT_CTL} ${OUTPUT_CTL}.tmp1
    fi
    TEMPLATE_ENS=""
    [ ${EDEF} -gt 1 ] && TEMPLATE_ENS="_bin%e"
#    TEMPLATE=${VAR}_%ch${TEMPLATE_ENS}.grd
    TEMPLATE="%ch\/${VAR}${TEMPLATE_ENS}.grd"
    sed ${OUTPUT_CTL}.tmp1 \
        -e "s/^DSET .*$/DSET \^${TEMPLATE}/" \
	-e "/^CHSUB .*/d"  \
	-e "s/^OPTIONS \(TEMPLATE\)*/OPTIONS TEMPLATE /i"  \
	-e "s/yrev//ig" \
	-e "s/^UNDEF .*$/UNDEF -0.99900E+35/i"  \
	-e "s/^TDEF .*$/TDEF   ${OUTPUT_TDEF}  LINEAR  ${OUTPUT_TDEF_START}  ${OUTPUT_TDEF_INCRE_GRADS}/"  \
	> ${OUTPUT_CTL}.tmp2
    sed -e "/^DSET/q" ${OUTPUT_CTL}.tmp2   > ${OUTPUT_CTL}
    cat ${OUTPUT_CTL}.chsub                >> ${OUTPUT_CTL}
    sed -e "0,/^DSET/d" ${OUTPUT_CTL}.tmp2 >> ${OUTPUT_CTL}
    rm ${OUTPUT_CTL}.tmp[12] ${OUTPUT_CTL}.chsub

    #=====================================#
    #      date loop (for each file)      #
    #=====================================#
    for(( d=1; ${d}<=${OUTPUT_TDEF}; d=${d}+${OUTPUT_TDEF_ONEFILE} )) ; do
	#
	if [ ${d} -eq 1 ] ; then
	    DATE_GRADS=${OUTPUT_TDEF_START}
	else
	    for(( dd=1; ${dd}<=${OUTPUT_TDEF_ONEFILE}; dd=${dd}+1 )) ; do
		DATE_GRADS=$( date -u --date "${DATE_GRADS} ${OUTPUT_TDEF_INCRE_SEC} seconds" +%H:%Mz%d%b%Y )
	    done
	fi
	DATE=$( date -u --date "${DATE_GRADS}" +%Y%m%d )
	DATE_SEC=$( date -u --date "${DATE_GRADS}" +%s )
	#
	if [ "${SA}" = "s" ] ; then
	    DATE_SEC_MIN=${DATE_SEC}
	    DATE_SEC_MAX=${DATE_SEC}
	elif [ "${SA}" = "a" ] ; then
	    DATE_SEC_MIN=$( echo "${DATE_SEC} - ${INPUT_TDEF_INCRE_SEC} / 2 " | bc )
	    DATE_SEC_MAX=$( echo "${DATE_SEC} - ${INPUT_TDEF_INCRE_SEC} / 2 + ${INPUT_TDEF_INCRE_SEC} * ${OUTPUT_TDEF_ONEFILE} " | bc )
	fi
	#
	TMP_SEC_MIN=$( date -u --date "00:00z${START_DATE}" +%s )
	TMP_SEC_MAX=$( date -u --date "00:00z${ENDPP_DATE}" +%s )
	if [ ${TMP_SEC_MIN} -gt ${DATE_SEC_MIN} -o ${TMP_SEC_MAX} -lt ${DATE_SEC_MAX} ] ; then
	    continue
	fi
	echo ${DATE_GRADS}
        #
        #----- set date for ${DATE} -----#
        #
	YEAR=${DATE:0:4}
	MONTH=${DATE:4:2}
	DAY=${DATE:6:2}
	#
        #----- get necessary input data -----#
	#
	TMIN=$( echo "(${d}-1)*${TSKIP}+1" | bc )
	TMAX=$( echo "(${d}+${OUTPUT_TDEF_ONEFILE}-1)*${TSKIP}" | bc )
	echo "${TMIN} ${TMAX}"
	#
	CHSUB_MIN=( $( grep CHSUB ${INPUT_CTL} | awk '{ print $2 }') )
	CHSUB_MAX=( $( grep CHSUB ${INPUT_CTL} | awk '{ print $3 }') )
	CHSUB_STR=( $( grep CHSUB ${INPUT_CTL} | awk '{ print $4 }') )
	IMIN=-1  # file number (min)
	IMAX=-1  # file number (max)
	for(( i=0; ${i}<=${#CHSUB_MIN[@]}-1; i=${i}+1 )) ; do
	    MATCH_FLAG=0
	    if [ ${CHSUB_MIN[$i]} -le ${TMIN} \
		-a                    ${TMIN} -le ${CHSUB_MAX[$i]} ] ; then
		IMIN=$i
	    fi
	    if [ ${CHSUB_MIN[$i]} -le ${TMAX} \
		-a                    ${TMAX} -le ${CHSUB_MAX[$i]} ] ; then
		IMAX=$i
	    fi
	done
	if [ ${IMIN} -eq -1 -o ${IMAX} -eq -1 ] ; then
	    echo "warning: ${INPUT_CTL} does not include ${DATE} <= date < ${DATE_NF}"
	    echo "##########"
	    continue
	fi
	#
	for(( e=1; ${e}<=${EDEF}; e=${e}+1 )) ; do
	    STR_ENS=""
	    if [ ${EDEF} -gt 1 ] ; then
		STR_ENS=${e}
		[ ${e} -lt 100 ] && STR_ENS="0${STR_ENS}"
		[ ${e} -lt 10  ] && STR_ENS="0${STR_ENS}"
		STR_ENS="_bin${STR_ENS}"
	    fi
#	    CONT_FLAG=0
#	    for(( i=${IMIN}; ${i}<=${IMAX}; i=${i}+1 )) ; do
#                # input file exists ?
#		INPUT_DATA=${INPUT_DIR}/${VAR}/${VAR}_${CHSUB_STR[$i]}${STR_ENS}.${EXT}
#		if [ ! -f ${INPUT_DATA} ] ; then
#		    echo "warning: ${INPUT_DATA} does not exist"
#		    echo "##########"
#		    continue 2
#		    CONT_FLAG=1
#		    break
#		fi
#		
#                # input data file size check
##		DATA_BYTE=4
##		CTL_UNIT=$( grads_ctl.pl ctl=${INPUT_CTL} key=VAR var=${VAR} target=UNITS )
##		[ "${CTL_UNIT}" = "-1,40,1" ] && DATA_BYTE=1
##		INPUT_TDEF=$( echo "${CHSUB_MAX[$i]} - ${CHSUB_MIN[$i]} + 1" | bc )
##		SIZE_IN=$( ls -lL ${INPUT_DATA} | awk '{ print $5 }' )
##		SIZE_IN_EXACT=$( echo ${DATA_BYTE}*${XDEF}*${YDEF}*${ZDEF}*${INPUT_TDEF} | bc )
##		if [ ${SIZE_IN} -ne ${SIZE_IN_EXACT} ] ; then
##		    echo "error: File size of ${INPUT_DATA} = ${SIZE_IN} is less than expected file size = ${SIZE_IN_EXACT}"
##		    exit 1
##		fi
#	    done
#	    [ ${CONT_FLAG} -eq 1 ] && continue 2
	    
	done
	#
        #----- output data -----#
	#
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
	    #
            # File name convention
            #   ms_tem_20040601.grd  (center of the date if incre > 1dy)
	    #
#	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_${YEAR}${MONTH}${DAY}${STR_ENS}.grd
	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${DATE}-${DATE}/${VAR}${STR_ENS}.grd

            # output file exist?
	    if [ -f ${OUTPUT_DATA} ] ; then
		SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' )
		SIZE_OUT_EXACT=$( echo 4*${XDEF}*${YDEF}*${ZDEF}*${VDEF}*${OUTPUT_TDEF_ONEFILE} | bc )
#	        echo 4*${XDEF}*${YDEF}*${ZDEF}*${OUTPUT_TDEF}
		if [ ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} \
		    -a "${OVERWRITE}" != "yes" \
		    -a "${OVERWRITE}" != "dry-rm" \
		    -a "${OVERWRITE}" != "rm" ] ; then
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

	#
	#----- output -----#
	#
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
#	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_${YEAR}${MONTH}${DAY}${STR_ENS}.grd
	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${DATE}-${DATE}/${VAR}${STR_ENS}.grd
	    mkdir -p ../${OUTPUT_DATA%${OUTPUT_DATA##*/}}

	    if [ "${SA}" = "s" ] ; then  # snapshot
		echo "  snapshot mode"
		echo ""
		if [ ${VDEF} -gt 1 ] ; then
		    echo "error: VDEF=${VDEF} in snapshot mode is NOT supported until now."
		    exit 1
		fi
		cat > temp.gs <<EOF
'reinit'
'xopen ../${INPUT_CTL}'
'set gxout fwrite'
'set fwrite -be temp.grd'
'set undef -0.99900E+35'
'set x 1 ${XDEF}'
'set y 1 ${YDEF}'
'set e ${e}'
t = ${TMIN} + ${TSKIP} - 1
while( t <= ${TMAX} )
  say 't = ' % t
  'set t 't
  z = 1
  while( z <= ${ZDEF} )
    say '  z = ' % z
    'set z 'z
    'd ${VAR}'
    z = z + 1
  endwhile
  t = t + ${TSKIP}
endwhile
'disable fwrite'
'quit'
EOF
#		cat all_all_multi_step_var.gs
	    elif [ "${SA}" = "a" ] ; then  # time mean
		echo "  average mode"
		echo ""

		cat > temp.gs <<EOF
'reinit'
'xopen ../${INPUT_CTL}'
'set gxout fwrite'
'set fwrite -be temp.grd'
'set undef -0.99900E+35'
'set x 1 ${XDEF}'
'set y 1 ${YDEF}'
'set e ${e}'
t = ${TMIN} + ${TSKIP} - 1
while( t <= ${TMAX} )
  tmin = t - ${TSKIP} + 1
  say 't : ' % tmin % ' - ' % t
EOF
		for SUBVAR in ${SUBVARS[@]} ; do
		    cat >> temp.gs <<EOF
  z = 1
  while( z <= ${ZDEF} )
    say '  z = ' % z
    'set z 'z
    say '    d ave(${SUBVAR},t='tmin',t='t')'
    'd ave(${SUBVAR},t='tmin',t='t')'
    z = z + 1
  endwhile
EOF
		done
		cat >> temp.gs <<EOF
  t = t + ${TSKIP}
endwhile
'disable fwrite'
'quit'
EOF
	    else
		echo "error: SA = ${SA} is not supported"
		exit 1
	    fi
#	    ${GRADS_CMD} -blc temp.gs || exit 1 #> grads.log
	    ${GRADS_CMD} -blcx temp.gs | tee grads.log.$$ 2>&1
	    if [ "$( grep -i error grads.log.$$ )" != "" ] ; then
		echo "error happened!  See grads.log.$$ for details."
		mv grads.log.$$ ${ORG_DIR}
		exit 1
	    fi
	    
	    mv grads.log.$$ ../${OUTPUT_DIR}/${VAR}/log/grads_${DATE}.log
	    mv temp.grd ../${OUTPUT_DATA}
	    rm temp.gs
	done

	cd - > /dev/null


    done
    
done

if [ ${NOTHING} -eq 1 ] ; then
    echo "info: nothing to do"
fi

exit
