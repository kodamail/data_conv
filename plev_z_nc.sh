#!/bin/bash
# p on z -> z on p
#
echo "########## $0 start ##########"
set -x
CNFID=$1       # CNFID (e.g. "def")
START_YMD=$2   # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$3   # YYYYMMDD (end+1 day of analysis period)
INPUT_DIR=$4   # input dir
OUTPUT_DIR=$5  # output dir
PDEF_LEVELS=$6 # pressure levels separated by comma
OVERWRITE=$7   # overwrite option (optional)
TARGET_VAR=$8  # variable name
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

PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1

NOTHING=1
#============================================================#
#
#  variable (=z) loop
#
#============================================================#
for VAR in m${TARGET_VAR:1:1}_z ; do
    VAR_PRES=m${TARGET_VAR:1:1}_pres
    #
    #----- check whether output dir is write-protected
    #
    if [[ -f "${OUTPUT_DIR}/${VAR}/_locked" ]] ; then
        echo "info: ${OUTPUT_DIR} is locked."
        continue
    fi
    mkdir -p ${OUTPUT_DIR}/${VAR}/log || exit 1
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
    #
    #----- get number of grids for input/output
    #
    INPUT_CTL=$( readlink -e ${INPUT_DIR}/${VAR_PRES}/${VAR_PRES}.ctl ) \
	|| { echo "warning: ${INPUT_CTL} does not exist." ; continue ; }
#    INPUT_CTL=${INPUT_DIR}/${VAR_PRES}/${VAR_PRES}.ctl
#    if [[ ! -f "${INPUT_CTL}" ]] ; then
#	echo "warning: ${INPUT_CTL} does not exist."
#	continue 
#    fi
    INPUT_CTL_META=$( ctl_meta ${INPUT_CTL} ) || exit 1
    DIMS=( $( grads_ctl.pl ${INPUT_CTL_META} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}
#    TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1

#    ZDEF_LEVELS_LIST=( $( grads_ctl.pl ../../g/g07f_1950/data_cmip6/ml_zlev/00640x00320x38/6hr_tstep/ms_pres/ms_pres_meta.ctl ZDEF ALL ) )

#    ZDEF_LEVELS=$( echo ${ZDEF_LEVELS_LIST[@]} | sed -e "s/ /,/g" )

#    DIMS=( $( grads_ctl.pl ${INPUT_CTL} DIMS NUM ) ) || exit 1
#    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}
#    TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
#    TDEF_START=$(     grads_ctl.pl ${INPUT_CTL} TDEF 1 ) || exit 1
#    TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_CTL} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
#    TDEF_INCRE_MN=$(  grads_ctl.pl ${INPUT_CTL} TDEF INC --unit MN  | sed -e "s/MN//"  ) || exit 1
    #
#    PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1
#    let TDEF_FILE=60*60*24/TDEF_INCRE_SEC       # number of time step per file
#    let TDEF_SEC_FILE=TDEF_INCRE_SEC*TDEF_FILE  # time in second per file
    #                                                                               START_HMS=$( date -u --date "${TDEF_START}" +%H%M%S )
#    TMP_H=${START_HMS:0:2}
#    TMP_M=${START_HMS:2:2}
#    let TMP_MN=TMP_H*60+TMP_M
    #
    #----- check existence of input data
    #
#    if [ "${START_HMS}" != "000000" ] ; then
#	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
#    else
#	FLAG=( $( grads_exist_data.sh ${INPUT_CTL} -ymd "[${START_YMD}:${ENDPP_YMD})" ) ) || exit 1
#    fi
#    if [ "${FLAG[0]}" != "ok" ] ; then
#	echo "warning: All or part of data does not exist (CTL=${INPUT_CTL})."
#	continue
#    fi

    #
    #---- generate control file (unified)
    #
    if [[ ! "${OVERWRITE}" =~ ^(dry-rm|rm)$ ]] ; then
	sed ${INPUT_CTL} -e "s|^DSET .*|DSET ^%ch.nc|" -e "/^CHSUB .*/d" -e "s/^${VAR_PRES}/${VAR}/" > ${OUTPUT_CTL}
	grep ^CHSUB ${INPUT_CTL} | sed -e "s|/|/${VAR}_|" -e "s|.000000||g" -e "s|-.*$||" >> ${OUTPUT_CTL}
    fi
    #
    # check existence of input data
    #
    TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${START_YMD} -gt ) || exit 1
    TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${ENDPP_YMD} -le ) || exit 1
    INPUT_DSET_LIST=( $( grads_ctl.pl ${INPUT_CTL} DSET "${TMIN}:${TMAX}" ) )
    INPUT_NC_LIST=()
    for INPUT_DSET in ${INPUT_DSET_LIST[@]} ; do
	INPUT_NC=$( readlink -e ${INPUT_DSET/^/${INPUT_CTL%/*}\//} ) \
	    || { echo "error: ${INPUT_DSET/^/${INPUT_CTL%/*}\//} does not exist." ; exit 1 ; }
	INPUT_NC_LIST+=( ${INPUT_NC} )
    done
    #
    #========================================#
    #  loop for each file
    #========================================#
    YMD_PREV=-1
    for(( d=0; $d<${#INPUT_NC_LIST[@]}; d=$d+1 )) ; do
	INPUT_NC=$(      readlink -e ${INPUT_NC_LIST[$d]}      ) || exit 1
	#
	TDEF_FILE=$( ncdump -h ${INPUT_NC} | grep "time =" | cut -d \; -f 1 |  cut -d = -f 2 )
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
        OUTPUT_NC=$( readlink -m ${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YMD}.nc )
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
        echo "YMD=${YMD}"

	#
	#----- z2pre
	#
	NOTHING=0
	cd ${TEMP_DIR}
	cat > z2pre.cnf <<EOF
&Z2PRE_PARAM
    imax      = ${XDEF},
    jmax      = ${YDEF},
    kmax      = ${ZDEF},
    tmax      = ${TDEF_FILE},
    pmax      = ${PDEF},
    varmax    = 1,
    plevel    = ${PDEF_LEVELS},
    varname   = '${VAR}',
    pname     = '${INPUT_NC}',
    outdir    = './',
    outsuffix = '_${YMD}.nc',
    input_netcdf  = .true.
    output_netcdf = .true.
    undef     = -99.9e+33,
    flag_z    = .true.,
/
EOF
	cat z2pre.cnf
	${BIN_Z2PRE} || exit 1
	if (( ${VERBOSE} >= 1 )) ; then
	    (( ${VERBOSE} >= 2 )) && cat z2pre.cnf
	    ${BIN_Z2PRE} || exit 1
	else
	    ${BIN_Z2PRE} > /dev/null || exit 1
	fi
	#
	mv ${VAR}_${YMD}.nc ${OUTPUT_NC} || exit 1
	cd - > /dev/null || exit 1
	mv ${TEMP_DIR}/z2pre.cnf ${OUTPUT_DIR}/${VAR}/log/z2pre_${YMD}.cnf
	#
	YMD_PREV=${YMD}
    done  # loop: d
done  # loop: VAR

(( ${NOTHING} == 1 )) && echo "info: Nothing to do."
echo "$0 normally finished."
echo
