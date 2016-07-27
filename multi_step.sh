#!/bin/sh
#
# *_step or *_mean
#
# WARNING: monthly mean is not supported (probably also in future!)
#
. ./common.sh || exit 1

echo "########## $0 start ##########"
set -x
START_YMD=$1      # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$2      # YYYYMMDD (end+1 day of analysis period)
INPUT_DIR=$3      # input dir
OUTPUT_DIR_TMP=$4 # output dir
OUTPUT_PERIOD=$5  # e.g. 1dy_mean, 6hr_tstep
OVERWRITE=$6      # overwrite option (optional)
TARGET_VAR=$7     # variable name (optional)
SA=$8             # optional, s:snapshot a:average
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

#
#----- derive parameters -----#
#
# OUTPUT_TYPE
#   tstep : following tstep file name (e.g. sa: mean  ss: snapshot)
#   mean  : always mean
OUTPUT_TYPE=$( echo ${OUTPUT_PERIOD} | cut -d _ -f 2 )  # mean or tstep

# e.g. "5 days", "1 hours"
OUTPUT_TDEF_INCRE_FILE=$( period_2_loop  ${OUTPUT_PERIOD} ) # >= 1 days
OUTPUT_TDEF_INCRE_FILE_SEC=$( echo ${OUTPUT_TDEF_INCRE_FILE} | sed -e "s/ days/\*24\*3600/" -e "s/ hours/\*3600/" | bc )
#
OUTPUT_TDEF_INCRE=$( period_2_incre ${OUTPUT_PERIOD} ) # native
OUTPUT_TDEF_INCRE_SEC=$( echo ${OUTPUT_TDEF_INCRE} | sed -e "s/ days/\*24\*3600/" -e "s/ hours/\*3600/" | bc )
OUTPUT_TDEF_INCRE_GRADS=$( echo "${OUTPUT_TDEF_INCRE}" | sed -e "s/ hours/hr/" -e "s/ days/dy/" )

NOTHING=1
#============================================================#
#
#  variable loop
#
#============================================================#
for VAR in ${VAR_LIST[@]} ; do
    #
    # SA
    #   s: snapshot  a: average
    #
    [ "${SA}" = "" ] && SA=${VAR:1:1}
    [ "${SA}" = "l" ] && SA="s"  # temporal
    [ "${OUTPUT_TYPE}" = "mean" ] && SA='a'  # force to specify "mean" even if the data is snapshot.
    OUTPUT_DIR=${OUTPUT_DIR_TMP}
    if [ "${SA}" = "a" ] ; then
	OUTPUT_DIR=$( echo ${OUTPUT_DIR_TMP} | sed -e "s/_tstep/_mean/" )
    fi
    echo "VAR=${VAR}, SA=${SA}, OUTPUT_DIR=${OUTPUT_DIR}"
    #
    #----- check whether output dir is write-protected
    #
    if [ -f "${OUTPUT_DIR}/${VAR}/_locked" ] ; then
        echo "info: ${OUTPUT_DIR} is locked."
        continue
    fi
    #
    #----- check existence of output data : TODO
    #
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
#    if [ -f "${OUTPUT_CTL}" ] ; then
    if [ -f "${OUTPUT_CTL}" -a "${OVERWRITE}" != "rm" -a "${OVERWRITE}" != "dry-rm" ] ; then
        FLAG=( $( grads_exist_data.sh ${OUTPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
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
    INPUT_TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    INPUT_TDEF_START=$(     grads_ctl.pl ${INPUT_CTL} TDEF 1 ) || exit 1
    INPUT_TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_CTL} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
    SUBVARS=( $(      grads_ctl.pl ${INPUT_CTL} VARS ALL ) ) || exit 1
    VDEF=${#SUBVARS[@]}
#    TSKIP=$( echo "${OUTPUT_TDEF_INCRE_SEC} / ${INPUT_TDEF_INCRE_SEC}" | bc )
    let TSKIP=OUTPUT_TDEF_INCRE_SEC/INPUT_TDEF_INCRE_SEC
    if [ ${TSKIP} -le 1 ] ; then
	echo "Nothing to do!"
	continue
    fi
    #                                                                                                 
    START_HMS=$( date -u --date "${INPUT_TDEF_START}" +%H%M%S )
    TMP_H=${START_HMS:0:2}
    TMP_M=${START_HMS:2:2}
    let TMP_MN=TMP_H*60+TMP_M
    #
    #----- check existence of input data
    #
    if [ "${START_HMS}" != "000000" ] ; then
	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
    else
	echo "It is not implemented!"
	exit 1
	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "[${START_YMD}:${ENDPP_YMD})" ) ) || exit 1
    fi
    if [ "${FLAG[0]}" != "ok" ] ; then
        echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})."
        continue
    fi
    #
    #----- derive OUTPUT_TDEF_START and OUTPUT_TDEF
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
    let OUTPUT_TDEF=INPUT_TDEF/TSKIP
    let OUTPUT_TDEF_FILE=OUTPUT_TDEF_INCRE_FILE_SEC/OUTPUT_TDEF_INCRE_SEC   # per one file
    echo "OUTPUT_TDEF_START = ${OUTPUT_TDEF_START}"
#    echo "OUTPUT_TDEF       = ${OUTPUT_TDEF}"
    #
    #---- generate control file (unified)
    #
    mkdir -p ${OUTPUT_DIR}/${VAR}/log
    if [ "${OVERWRITE}" != "rm" -a "${OVERWRITE}" != "dry-rm" ] ; then
	grads_ctl.pl ${INPUT_CTL} > ${OUTPUT_CTL}.tmp1 || exit 1
        #
	rm -f ${OUTPUT_CTL}.chsub
	DATE=$( date -u --date "${OUTPUT_TDEF_START}" +%Y%m%d\ %H:%M:%S ) || exit 1  # YYYYMMDD HH:MM:SS
	echo "CHSUB  1  ${OUTPUT_TDEF_FILE}  ${DATE:0:4}/${VAR}_${DATE:0:8}" >> ${OUTPUT_CTL}.chsub
	for(( d=1+${OUTPUT_TDEF_FILE}; ${d}<=${OUTPUT_TDEF}; d=${d}+${OUTPUT_TDEF_FILE} )) ; do
            let CHSUB_MAX=d+OUTPUT_TDEF_FILE-1
            DATE=$( date -u --date "${DATE} ${OUTPUT_TDEF_INCRE_FILE_SEC} seconds" +%Y%m%d\ %H:%M:%S ) || exit 1
            echo "CHSUB  ${d}  ${CHSUB_MAX}  ${DATE:0:4}/${VAR}_${DATE:0:8}" >> ${OUTPUT_CTL}.chsub
	done
	TEMPLATE_ENS=""
	[ ${EDEF} -gt 1 ] && TEMPLATE_ENS="_bin%e"
#    TEMPLATE=${VAR}_%ch${TEMPLATE_ENS}.grd
#    TEMPLATE="%ch\/${VAR}${TEMPLATE_ENS}.grd"
	TEMPLATE="%ch${TEMPLATE_ENS}.grd"
	sed ${OUTPUT_CTL}.tmp1 \
            -e "s|^DSET .*$|DSET \^${TEMPLATE}|" \
	    -e "/^CHSUB .*/d"  \
	    -e "s/^OPTIONS \(TEMPLATE\)*/OPTIONS TEMPLATE BIG_ENDIAN/i"  \
	    -e "s/yrev//ig" \
	    -e "s/^UNDEF .*$/UNDEF -0.99900E+35/i"  \
	    -e "s/^TDEF .*$/TDEF   ${OUTPUT_TDEF}  LINEAR  ${OUTPUT_TDEF_START}  ${OUTPUT_TDEF_INCRE_GRADS}/"  \
	    > ${OUTPUT_CTL}.tmp2
#        -e "s/^DSET .*$/DSET \^${TEMPLATE}/" \
	sed -e "/^DSET/q" ${OUTPUT_CTL}.tmp2   > ${OUTPUT_CTL}
	cat ${OUTPUT_CTL}.chsub                >> ${OUTPUT_CTL}
	sed -e "0,/^DSET/d" ${OUTPUT_CTL}.tmp2 >> ${OUTPUT_CTL}
	rm ${OUTPUT_CTL}.tmp[12] ${OUTPUT_CTL}.chsub
    fi
    #
    #========================================#
    #  date loop (for each file)
    #========================================#
    for(( d=1; ${d}<=${OUTPUT_TDEF}; d=${d}+${OUTPUT_TDEF_FILE} )) ; do
        #
        #----- set/proceed date -----#
        #
        if [ ${d} -eq 1 ] ; then
            DATE=$( date -u --date "${OUTPUT_TDEF_START}" +%Y%m%d\ %H:%M:%S ) || exit 1
        else
            DATE=$( date -u --date "${DATE} ${OUTPUT_TDEF_INCRE_FILE_SEC} seconds" +%Y%m%d\ %H:%M:%S ) || exit 1
        fi
        YMD=${DATE:0:8}
        #
        [ ${YMD} -lt ${START_YMD} ] && continue
        [ ${YMD} -ge ${ENDPP_YMD} ] && break
        #
        YMDPP=$( date -u --date "${YMD} 1 day" +%Y%m%d ) || exit 1
        YEAR=${DATE:0:4} ; MONTH=${DATE:4:2} ; DAY=${DATE:6:2}
	#
        DATE_SEC=$( date -u --date "${DATE}" +%s ) || exit 1
	if [ "${SA}" = "s" ] ; then
	    DATE_SEC_MIN=${DATE_SEC}
	    DATE_SEC_MAX=${DATE_SEC}
	elif [ "${SA}" = "a" ] ; then
	    DATE_SEC_MIN=$( echo "${DATE_SEC} - ${INPUT_TDEF_INCRE_SEC} / 2 " | bc )
	    DATE_SEC_MAX=$( echo "${DATE_SEC} - ${INPUT_TDEF_INCRE_SEC} / 2 + ${INPUT_TDEF_INCRE_SEC} * ${OUTPUT_TDEF_FILE} " | bc )
	fi
	TMP_SEC_MIN=$( date -u --date "${START_YMD} 00:00" +%s )
	TMP_SEC_MAX=$( date -u --date "${ENDPP_YMD} 00:00" +%s )
	if [ ${TMP_SEC_MIN} -gt ${DATE_SEC_MIN} -o ${TMP_SEC_MAX} -lt ${DATE_SEC_MAX} ] ; then
	    continue
	fi
	#
        #----- output data -----#
	#
        # File name convention
        #   2004/ms_tem_20040601.grd  (center of the date if incre > 1dy)
        #
        mkdir -p ${OUTPUT_DIR}/${VAR}/${YEAR} || exit 1
	for(( e=1; ${e}<=${EDEF}; e=${e}+1 )) ; do
	    STR_ENS=""
	    TEMPLATE_ENS=""
            if [ ${EDEF} -gt 1 ] ; then
                STR_ENS=$( printf "%03d" ${e} ) || exit 1
                STR_ENS="_bin${STR_ENS}"
            fi
	    #
	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YMD}${STR_ENS}.grd
            #
            #----- output file exist?
            #
	    if [ -f "${OUTPUT_DATA}" ] ; then
		SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' )
		SIZE_OUT_EXACT=$( echo 4*${XDEF}*${YDEF}*${ZDEF}*${VDEF}*${OUTPUT_TDEF_FILE} | bc )
		if [ ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} -a "${OVERWRITE}" != "yes" \
		    -a "${OVERWRITE}" != "dry-rm" -a "${OVERWRITE}" != "rm" ] ; then
		    continue 2
		fi
		echo "Removing ${OUTPUT_DATA}"
		echo ""
		[ "${OVERWRITE}" = "dry-rm" ] && continue 1
		rm -f ${OUTPUT_DATA}
	    fi
	done
	[ "${OVERWRITE}" = "rm" -o "${OVERWRITE}" = "dry-rm" ] && continue 1
	#
        #----- get TMIN/TMAX -----#
	#
	TMIN=$( echo "(${d}-1)*${TSKIP}+1" | bc ) || exit 1
	TMAX=$( echo "(${d}+${OUTPUT_TDEF_FILE}-1)*${TSKIP}" | bc ) || exit 
        echo "YMD=${YMD} INPUT_T=${TMIN} ${TMAX}"
	NOTHING=0

	#
	#----- output -----#
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
	    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YMD}${STR_ENS}.grd

	    if [ "${SA}" = "s" ] ; then  # snapshot
#		echo "  snapshot mode"
#		echo ""
		if [ ${VDEF} -gt 1 ] ; then
		    echo "error: VDEF=${VDEF} in snapshot mode is NOT supported until now."
		    exit 1
		fi
		cat > temp.gs <<EOF
'reinit'
rc = gsfallow( 'on' )
'xopen ../${INPUT_CTL}'
'set gxout fwrite'
'set fwrite -be temp.grd'
'set undef -0.99900E+35'
'set x 1 ${XDEF}'
'set y 1 ${YDEF}'
'set e ${e}'
t = ${TMIN} + ${TSKIP} - 1
while( t <= ${TMAX} )
  prex( 'set t 't )
  z = 1
  while( z <= ${ZDEF} )
    prex( 'set z 'z )
    'd ${VAR}'
    z = z + 1
  endwhile
  t = t + ${TSKIP}
endwhile
'disable fwrite'
'quit'
EOF
	    elif [ "${SA}" = "a" ] ; then  # time mean
#		echo "  average mode"
#		echo ""

		cat > temp.gs <<EOF
'reinit'
rc = gsfallow( 'on' )
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
*  say 't : ' % tmin % ' - ' % t
EOF
		for SUBVAR in ${SUBVARS[@]} ; do
		    cat >> temp.gs <<EOF
  z = 1
  while( z <= ${ZDEF} )
    prex( 'set z 'z )
    prex( 'd ave(${SUBVAR},t='tmin',t='t')' )
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

            if [ ${VERBOSE} -ge 1 ] ; then
                [ ${VERBOSE} -ge 2 ] && cat temp.gs
                grads -blc temp.gs || exit 1
            else
                grads -blc temp.gs > temp.log || { cat temp.log ; exit 1 ; }
            fi
	    mv temp.log ../${OUTPUT_DIR}/${VAR}/log/grads_${YMD}.log || exit 1
	    mv temp.grd ../${OUTPUT_DATA} || exit 1
	    rm temp.gs
	done

	cd - > /dev/null
    done
    
done

[ ${NOTHING} -eq 1 ] && echo "info: Nothing to do."
echo "$0 normally finished."
echo
