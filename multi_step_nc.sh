#!/bin/bash
#
# *_step or *_mean
#
# WARNING: monthly mean is not supported (probably also in future!)
#
#. ./common.sh || exit 1

echo "########## $0 start ##########"
set -x
CNFID=$1       # CNFID (e.g. "def")
START_YMD=$2      # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$3      # YYYYMMDD (end+1 day of analysis period)
INPUT_DIR=$4      # input dir
OUTPUT_DIR_TMP=$5 # output dir
OUTPUT_PERIOD=$6  # e.g. 1dy_mean, 6hr_tstep
OVERWRITE=$7      # overwrite option (optional)
INC_SUBVARS=$8    # SUBVARS option (optional)
TARGET_VAR=$9     # variable name (optional)
SA=${10}          # optional, s:snapshot a:average
set +x
echo "##########"

source ./common.sh ${CNFID} || exit 1

create_temp || exit 1
TEMP_DIR=${BASH_COMMON_TEMP_DIR}
trap "finish" 0

if [[ ! "${OVERWRITE}" =~ ^(|yes|no|dry-rm|rm)$ ]] ; then
    echo "error: OVERWRITE = ${OVERWRITE} is not supported yet." >&2
    exit 1
fi

if [[ "${TARGET_VAR}" = "" ]] ; then
    VAR_LIST=( $( ls ${INPUT_DIR}/ ) ) || exit 1
else
    VAR_LIST=( ${TARGET_VAR} )
fi

FLAG_HALF=0
if [[ "${OUTPUT_PERIOD}" =~ half$ ]] ; then
    FLAG_HALF=1
fi
if [[ ${FLAG_HALF} = 1 ]] ; then
    echo "error: FLAG_HALF is not supported"
    exit 1
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
    [[ "${SA}" = "" ]] && SA=${VAR:1:1}
#    [[ "${SA}" = "l" ]] && SA="s"  # temporal
    [[ "${OUTPUT_TYPE}" = "mean" ]] && SA='a'  # force to specify "mean" even if the data is snapshot.
    [[ "${SA}" = "l" ]] && { echo "error: specify snapshot/average for ${VAR}" ; exit 1 ; }
    OUTPUT_DIR=${OUTPUT_DIR_TMP}
    if [[ "${SA}" = "a" ]] ; then
	OUTPUT_DIR=$( echo ${OUTPUT_DIR_TMP} | sed -e "s/_tstep/_mean/" )
    fi
    echo "VAR=${VAR}, SA=${SA}, OUTPUT_DIR=${OUTPUT_DIR}"
    #
    #----- check whether output dir is write-protected
    #
    if [[ -f "${OUTPUT_DIR}/${VAR}/_locked" ]] ; then
        echo "info: ${OUTPUT_DIR} is locked."
        continue
    fi

    mkdir -p ${OUTPUT_DIR}/${VAR}/log || exit 1
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
##    if [ -f "${OUTPUT_CTL}" ] ; then
#    if [ -f "${OUTPUT_CTL}" -a "${OVERWRITE}" != "rm" -a "${OVERWRITE}" != "dry-rm" ] ; then
#        FLAG=( $( grads_exist_data.sh ${OUTPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
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
    INPUT_CTL_META=$( ctl_meta ${INPUT_CTL} ) || exit 1
    DIMS=( $( grads_ctl.pl ${INPUT_CTL_META} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}
    INPUT_TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    INPUT_TDEF_START=$(     grads_ctl.pl ${INPUT_CTL_META} TDEF 1 ) || exit 1
    INPUT_TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_CTL_META} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
    SUBVARS=( ${VAR} )
    if [[ "${INC_SUBVARS}" = "yes" ]] ; then
	SUBVARS=( $( grads_ctl.pl ${INPUT_CTL_META} VARS ALL ) ) || exit 1
    fi
    VDEF=${#SUBVARS[@]}
#    TSKIP=$( echo "${OUTPUT_TDEF_INCRE_SEC} / ${INPUT_TDEF_INCRE_SEC}" | bc )
    let TSKIP=OUTPUT_TDEF_INCRE_SEC/INPUT_TDEF_INCRE_SEC
#    if [ ${TSKIP} -le 1 ] ; then
    if (( ${TSKIP} <= 1 )) ; then
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
    if [[ "${START_HMS}" != "000000" ]] ; then
#	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
	TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${START_YMD} -gt ) || exit 1
	TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${ENDPP_YMD} -le ) || exit 1
    else
#	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "[${START_YMD}:${ENDPP_YMD})" ) ) || exit 1
	TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${START_YMD} -ge ) || exit 1
	TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${ENDPP_YMD} -lt ) || exit 1
    fi
#    TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${START_YMD} -gt ) || exit 1
#    TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${ENDPP_YMD} -le ) || exit 1
    INPUT_DSET_LIST=( $( grads_ctl.pl ${INPUT_CTL} DSET "${TMIN}:${TMAX}" ) )
    INPUT_NC_LIST=()
    for INPUT_DSET in ${INPUT_DSET_LIST[@]} ; do
	INPUT_NC_TMP=${INPUT_DSET/^/${INPUT_CTL%/*}\//}
	INPUT_NC=$( readlink -e ${INPUT_NC_TMP} ) \
	    || { echo "error: ${INPUT_NC_TMP} does not exist." ; exit 1 ; }
	INPUT_NC_LIST+=( ${INPUT_NC} )
    done

#    if [ "${FLAG[0]}" != "ok" ] ; then
#        echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})."
#        continue
#    fi
    #
    #----- derive OUTPUT_TDEF_START and OUTPUT_TDEF
    #
    if [[ "${SA}" = "s" ]] ; then
	OUTPUT_TDEF_START=$( date -u --date "${INPUT_TDEF_START}" +%H:%Mz%d%b%Y )
	for(( i=2; $i<=${TSKIP}; i=$i+1 )) ; do
	    OUTPUT_TDEF_START=$( date -u --date "${OUTPUT_TDEF_START} ${INPUT_TDEF_INCRE_SEC} seconds" +%H:%Mz%d%b%Y )
	done
	    
    elif [[ "${SA}" = "a" ]] ; then
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
    if [[ ! "${OVERWRITE}" =~ ^(dry-rm|rm)$ ]] ; then
	sed ${INPUT_CTL_META} \
	    -e "s|^DSET .*|DSET ^%ch.nc|" \
	    -e "/^CHSUB .*/d" \
	    -e "s/^TDEF .*$/TDEF  time  ${OUTPUT_TDEF}  LINEAR  ${OUTPUT_TDEF_START}  ${OUTPUT_TDEF_INCRE_GRADS}/" \
	    > ${OUTPUT_CTL}
	grep ^CHSUB ${INPUT_CTL} | awk -v TSKIP=${TSKIP} '{ print $1,($2-1)/TSKIP+1,$3/TSKIP,$4 }' | sed -e "s|/${VAR}/|/|" -e "s|.000000||g" -e "s|-.*$||" >> ${OUTPUT_CTL}
#	grep ^CHSUB ${INPUT_CTL} | awk -v TSKIP=${TSKIP} '{ print $1,($2-1)/TSKIP+1,$3/TSKIP,$4 }' | sed -e "s|/|/${VAR}_|" -e "s|.000000||g" -e "s|-.*$||" >> ${OUTPUT_CTL}

#	grep ^CHSUB ${INPUT_CTL_REF} | sed -e "s|/|/${VAR}_|" -e "s|.000000||g" -e "s|-.*$||" >> ${OUTPUT_CTL}
    fi

    #
    #========================================#
    #  loop for each file
    #========================================#
    YMD_PREV=-1
    for INPUT_NC in ${INPUT_NC_LIST[@]} ; do

#	TDEF_FILE=$( ${BIN_CDO} -s ntime ${INPUT_NC} )
	TDEF_FILE=$( cdo -s ntime ${INPUT_NC} ) || exit 1
	YMD_GRADS=$( grads_ctl.pl ${INPUT_NC} TDEF 1 )
        YMD=$( date -u --date "${YMD_GRADS}" +%Y%m%d ) || exit 1
	(( ${YMD} == ${YMD_PREV} )) && { echo "error: time interval less than 1-dy is not supported now" ; exit 1 ; }
	YEAR=${YMD:0:4}
        #
        #----- output data
        #
        # File name convention (YMD = first day)
        #   2004/ms_tem_${YMD}.nc
        #
        #OUTPUT_NC=$( readlink -m ${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YMD}.nc )
        OUTPUT_NC=$( readlink -m ${OUTPUT_DIR}/${VAR}/${YEAR}/${INPUT_NC##*/} )

	#
	# check existence of output data
	#
	if [[ -f "${OUTPUT_NC}" ]] ; then
	    [[ ! "${OVERWRITE}" =~ ^(yes|dry-rm|rm)$ ]] && continue
	    echo "Removing ${OUTPUT_NC}." ; echo ""
	    [[ "${OVERWRITE}" = "dry-rm" ]] && continue
	    rm -f ${OUTPUT_NC}
	fi
	[[ "${OVERWRITE}" =~ ^(dry-rm|rm)$ ]] && continue
	#
	mkdir -p ${OUTPUT_NC%/*} || exit 1
        #echo "YMD=${YMD}"
	echo
        echo "Input: ${INPUT_NC}"
        echo "    -> ${OUTPUT_NC}"
	NOTHING=0
	#
	if [[ "${SA}" = "s" ]] ; then  # snapshot
	    TLIST=$( seq -s , ${TSKIP} ${TSKIP} ${TDEF_FILE} )
#	    ${BIN_CDO} -s -b 32 seltimestep,${TLIST} ${INPUT_NC} ${TEMP_DIR}/tmp.nc || exit 1
	    cdo -s -b 32 seltimestep,${TLIST} ${INPUT_NC} ${TEMP_DIR}/tmp.nc || exit 1
	    mv ${TEMP_DIR}/tmp.nc ${OUTPUT_NC} || exit 1

	elif [[ "${SA}" = "a" ]] ; then  # time mean
#	    ${BIN_CDO} -s -b 32 timselmean,${TSKIP} ${INPUT_NC} ${TEMP_DIR}/tmp.nc || exit 1
	    cdo -s -b 32 timselmean,${TSKIP} ${INPUT_NC} ${TEMP_DIR}/tmp.nc || exit 1
	    mv ${TEMP_DIR}/tmp.nc ${OUTPUT_NC} || exit 1
	else
	    echo "error: SA = ${SA} is not supported"
	    exit 1
	fi
    done
done  # loop: VAR

(( ${NOTHING} == 1 )) && echo "info: Nothing to do."
echo "$0 normally finished ($(date))."
echo
