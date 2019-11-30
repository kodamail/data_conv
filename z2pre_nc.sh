#!/bin/bash
#
# convert from z to p coordinate
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
TARGET_VAR=$8  # variable name (optional)
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

NOTHING=1
#============================================================#
#
#  variable loop
#
#============================================================#
for VAR in ${VAR_LIST[@]} ; do
    VAR_PRES=m${VAR:1:1}_pres
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
    INPUT_CTL=$(      readlink -e ${INPUT_DIR}/${VAR}/${VAR}.ctl ) \
	|| { echo "warning: ${INPUT_CTL} does not exist." ; continue ; }
    INPUT_PRES_CTL=$( readlink -e ${INPUT_DIR}/${VAR_PRES}/${VAR_PRES}.ctl ) \
	|| { echo "warning: ${INPUT_PRES_CTL} does not exist." ; continue ; }
    INPUT_CTL_META=$( ctl_meta ${INPUT_CTL} ) || exit 1
    DIMS=( $( grads_ctl.pl ${INPUT_CTL_META} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}
#    TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1
    #
    #---- generate control file (unified)
    #
    if [[ ! "${OVERWRITE}" =~ ^(dry-rm|rm)$ ]] ; then
	sed ${INPUT_CTL} -e "s|^DSET .*|DSET ^%ch.nc|" -e "/^CHSUB .*/d" > ${OUTPUT_CTL}
	grep ^CHSUB ${INPUT_CTL} | sed -e "s|/|/${VAR}_|" -e "s|.000000||g" -e "s|-.*$||" >> ${OUTPUT_CTL}
    fi
    # dummy control file for obtaining metadata
    sed ${OUTPUT_CTL} -e "/^CHSUB/d" > ${OUTPUT_CTL%.ctl}_meta.ctl
    cat ${OUTPUT_CTL} | grep ^CHSUB | head -n 1 >> ${OUTPUT_CTL%.ctl}_meta.ctl
    #
    # check existence of input data
    #
    TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${START_YMD} -gt ) || exit 1
    TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${ENDPP_YMD} -le ) || exit 1
    INPUT_DSET_LIST=(      $( grads_ctl.pl ${INPUT_CTL}      DSET "${TMIN}:${TMAX}" ) )
    INPUT_PRES_DSET_LIST=( $( grads_ctl.pl ${INPUT_PRES_CTL} DSET "${TMIN}:${TMAX}" ) )
    INPUT_NC_LIST=()
    INPUT_PRES_NC_LIST=()
    for INPUT_DSET in ${INPUT_DSET_LIST[@]} ; do
	INPUT_NC=$( readlink -e ${INPUT_DSET/^/${INPUT_CTL%/*}\//} ) \
	    || { echo "error: ${INPUT_DSET/^/${INPUT_CTL%/*}\//} does not exist." ; exit 1 ; }
	INPUT_NC_LIST+=( ${INPUT_NC} )
    done
    for INPUT_PRES_DSET in ${INPUT_PRES_DSET_LIST[@]} ; do
#echo ${INPUT_PRES_DSET}
	INPUT_PRES_NC=$( readlink -e ${INPUT_PRES_DSET/^/${INPUT_PRES_CTL%/*}\//} ) \
	    || { echo "error: ${INPUT_PRES_DSET/^/${INPUT_PRES_CTL%/*}\//} does not exist." ; exit 1 ; }
	INPUT_PRES_NC_LIST+=( ${INPUT_PRES_NC} )
    done
    #
    #========================================#
    #  loop for each file
    #========================================#
    YMD_PREV=-1
    for(( d=0; $d<${#INPUT_NC_LIST[@]}; d=$d+1 )) ; do
	INPUT_NC=$(      readlink -e ${INPUT_NC_LIST[$d]}      ) || exit 1
	INPUT_PRES_NC=$( readlink -e ${INPUT_PRES_NC_LIST[$d]} ) || exit 1
	#
#	TDEF_FILE=$( ncdump -h ${INPUT_NC} | grep "time =" | cut -d \; -f 1 |  cut -d = -f 2 )
	TDEF_FILE=$( cdo -s ntime ${INPUT_NC} )
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
    indir     = '${INPUT_NC%/*}',
    varname   = '${VAR}',
    insuffix  = '${INPUT_NC##*${VAR}}',
    pname     = '${INPUT_PRES_NC}',
    outdir    = './',
    outsuffix = '_${YMD}.nc',
    input_netcdf  = .true.
    output_netcdf = .true.
    undef     = -99.9e+33,      !
/
EOF
#    insuffix  = '.nc',
#	cat z2pre.cnf
#	${BIN_Z2PRE} 
	# TODO: error handling
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
