#!/bin/bash
#
# derive variables
#
echo "########## $0 start ##########"
set -x
CNFID=$1       # CNFID (e.g. "def")
START_YMD=$2   # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$3   # YYYYMMDD (end+1 day of analysis period)
INPUT_DIR=$4   # input dir
OUTPUT_DIR=$5  # output dir
OVERWRITE=$6   # overwrite option (optional)
TARGET_VAR=$7
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
    echo "error: VAR is not set." >&2
    exit 1
fi

VAR_LIST=( ${TARGET_VAR} )

NOTHING=1
#============================================================#
#
#  variable loop
#
#============================================================#
for VAR in ${VAR_LIST[@]} ; do
    #
    #----- check whether output dir is write-protected
    #
    if [[ -f "${INPUT_DIR}/${VAR}/_locked" ]] ; then
	echo "info: ${INPUT_DIR} is locked."
	continue
    fi
    mkdir -p ${OUTPUT_DIR}/${VAR}/log || exit 1
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl

    INPUT_CTL_LIST=()
    VAR_IN=()
    case "${VAR:3}" in
      "omega")
        INPUT_CTL_W=$( readlink -e ${INPUT_DIR}/${VAR:0:3}w/${VAR:0:3}w.ctl ) \
	    || { echo "warning: ${INPUT_DIR}/${VAR:0:3}w/${VAR:0:3}w.ctl does not exist." ; continue ; }
	VAR_W=${VAR:0:3}w

	INPUT_CTL_TEM=$( readlink -e ${INPUT_DIR}/${VAR:0:3}tem/${VAR:0:3}tem.ctl ) \
	    || { echo "warning: ${INPUT_DIR}/${VAR:0:3}tem/${VAR:0:3}tem.ctl does not exist." ; continue ; }
	VAR_TEM=${VAR:0:3}tem
	
	INPUT_CTL_PRES=$( readlink -e ${INPUT_DIR}/${VAR:0:3}pres/${VAR:0:3}pres.ctl ) \
	    || { echo "warning: ${INPUT_DIR}/${VAR:0:3}pres/${VAR:0:3}pres.ctl does not exist." ; continue ; }
	VAR_PRES=${VAR:0:3}pres
	
	INPUT_CTL_REF=${INPUT_CTL_W}
	VAR_REF=${VAR_W}
	    
#	    for V in w tem pres ; do
#		INPUT_CTL_LIST+=( $( readlink -e ${INPUT_DIR}/${VAR:0:3}${V}/${VAR:0:3}${V}.ctl ) ) \
#		    || { echo "warning: ${INPUT_DIR}/${VAR:0:3}${V}/${VAR:0:3}${V}.ctl does not exist." ; continue ; }
#		VAR_IN+=( ${VAR:0:3}${V})
#	    done
	;;
#	"s${SA}_ws10m")
#	    exit 1
#	    INPUT_CTL_LIST=( 
#		${INPUT_DIR}/s${SA}_u10m/s${SA}_u10m.ctl
#		${INPUT_DIR}/s${SA}_v10m/s${SA}_v10m.ctl
#		)
##	    INPUT_VAR_REF=ss_u10m
#	    GRADS_VAR="sqrt(s${SA}_u10m.1*s${SA}_u10m.1+s${SA}_v10m.2*s${SA}_v10m.2)"
#	    ;;
      "ws")
        INPUT_CTL_U=$( readlink -e ${INPUT_DIR}/${VAR:0:3}u/${VAR:0:3}u.ctl ) \
	    || { echo "warning: ${INPUT_DIR}/${VAR:0:3}u/${VAR:0:3}u.ctl does not exist." ; continue ; }
	VAR_U=${VAR:0:3}u

        INPUT_CTL_V=$( readlink -e ${INPUT_DIR}/${VAR:0:3}v/${VAR:0:3}v.ctl ) \
	    || { echo "warning: ${INPUT_DIR}/${VAR:0:3}v/${VAR:0:3}v.ctl does not exist." ; continue ; }
	VAR_V=${VAR:0:3}v
	INPUT_CTL_REF=${INPUT_CTL_U}
	VAR_REF=ms_u_p850
	#GRADS_VAR="sqrt(${VAR:0:3}u.1*${VAR:0:3}u.1+${VAR:0:3}v.2*${VAR:0:3}v.2)"
	;;
      *)
        echo "error: ${VAR} is not supported."
	exit 1
	;;
    esac
    #
    #----- get number of grids for input/output
    #
    INPUT_CTL_META=$( ctl_meta ${INPUT_CTL_REF} ) || exit 1
    DIMS=( $( grads_ctl.pl ${INPUT_CTL_META} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}
    #
    #---- generate control file (unified)
    #
    if [[ ! "${OVERWRITE}" =~ ^(dry-rm|rm)$ ]] ; then
	#sed ${INPUT_CTL_META} -e "s|^DSET .*|DSET ^%ch.nc|" -e "/^CHSUB .*/d" -e "s/^${VAR_REF}.*$/${VAR}/" > ${OUTPUT_CTL}
	sed ${INPUT_CTL_META} -e "s|^DSET .*|DSET ^%ch.nc|" -e "/^CHSUB .*/d" -e "/^VARS/,/^ENDVARS/d" > ${OUTPUT_CTL}
	#sed ${INPUT_CTL_META} -e "s|^DSET .*|DSET ^%ch.nc|" -e "/^CHSUB .*/d" -e "s|${VAR_REF}/${VAR}/" -e "/^VARS/,/^ENDVARS/d" > ${OUTPUT_CTL}
	grep ^CHSUB ${INPUT_CTL_REF} | sed -e "s|/${VAR_REF}/|/|" -e "s|/${VAR_REF}_|/|" \
	    | sed -e "s|/|/${VAR}_|" -e "s|.000000||g" -e "s|-.*$||" >> ${OUTPUT_CTL}
    fi
    #
    #----- check existence of input data
    #
    TMIN=$( grads_time2t.sh ${INPUT_CTL_META} ${START_YMD} -gt ) || exit 1
    TMAX=$( grads_time2t.sh ${INPUT_CTL_META} ${ENDPP_YMD} -le ) || exit 1
    INPUT_DSET_LIST=( $( grads_ctl.pl ${INPUT_CTL_REF} DSET "${TMIN}:${TMAX}" ) )

    case "${VAR:3}" in
      "omega")
        INPUT_W_NC_LIST=()
	INPUT_TEM_NC_LIST=()
	INPUT_PRES_NC_LIST=()
	for INPUT_DSET in ${INPUT_DSET_LIST[@]} ; do
	    INPUT_W_NC=$( readlink -e ${INPUT_DSET/^/${INPUT_CTL_META%/*}\//} ) \
		|| { echo "error: ${INPUT_DSET/^/${INPUT_CTL_META%/*}\//} does not exist." ; exit 1 ; }
	    INPUT_W_NC_LIST+=( ${INPUT_W_NC} )
	    
	    INPUT_TEM_NC=$( readlink -e ${INPUT_W_NC//${VAR_W}/${VAR_TEM}} ) \
		|| { echo "error: ${INPUT_W_NC//${VAR_W}/${VAR_TEM}} does not exist." ; exit 1 ; }
	    [[ "${INPUT_TEM_NC}" == "${INPUT_W_NC}" ]] \
		&& { echo "duplicate error" ; exit 1 ; }
	    INPUT_TEM_NC_LIST+=( ${INPUT_TEM_NC} )
	    
	    INPUT_PRES_NC=$( readlink -e ${INPUT_W_NC//${VAR_W}/${VAR_PRES}} ) \
		|| { echo "error: ${INPUT_W_NC//${VAR_W}/${VAR_PRES}} does not exist." ; exit 1 ; }
	    [[ "${INPUT_PRES_NC}" == "${INPUT_W_NC}" ]] \
		&& { echo "duplicate error" ; exit 1 ; }
	    INPUT_PRES_NC_LIST+=( ${INPUT_PRES_NC} )
	done
	;;
      "ws")
        INPUT_U_NC_LIST=()
        INPUT_V_NC_LIST=()
	for INPUT_DSET in ${INPUT_DSET_LIST[@]} ; do
	    INPUT_U_NC=$( readlink -e ${INPUT_DSET/^/${INPUT_CTL_META%/*}\//} ) \
		|| { echo "error: ${INPUT_DSET/^/${INPUT_CTL_META%/*}\//} does not exist." ; exit 1 ; }
	    INPUT_U_NC_LIST+=( ${INPUT_U_NC} )
	    
	    INPUT_V_NC=$( readlink -e ${INPUT_U_NC//${VAR_U}/${VAR_V}} ) \
		|| { echo "error: ${INPUT_U_NC//${VAR_U}/${VAR_V}} does not exist." ; exit 1 ; }
	    [[ "${INPUT_V_NC}" == "${INPUT_U_NC}" ]] \
		&& { echo "duplicate error" ; exit 1 ; }
	    INPUT_V_NC_LIST+=( ${INPUT_V_NC} )
	done
	;;
    esac
    #
    #========================================#
    #  loop for each file
    #========================================#
    YMD_PREV=-1
    # omega
    for(( d=0; $d<${#INPUT_W_NC_LIST[@]}; d=$d+1 )) ; do
	INPUT_W_NC=${INPUT_W_NC_LIST[$d]}
	INPUT_TEM_NC=${INPUT_TEM_NC_LIST[$d]}
	INPUT_PRES_NC=${INPUT_PRES_NC_LIST[$d]}
	INPUT_U_NC=${INPUT_U_NC_LIST[$d]}
	INPUT_V_NC=${INPUT_U_NC_LIST[$d]}
	INPUT_REF_NC=${INPUT_W_NC}
	#
#	TDEF_FILE=$( ncdump -h ${INPUT_REF_NC} | grep "time =" | cut -d \; -f 1 |  cut -d = -f 2 )
	TDEF_FILE=$( cdo -s ntime ${INPUT_REF_NC} )
	YMD_GRADS=$( grads_ctl.pl ${INPUT_REF_NC} TDEF 1 )
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
	#----- diagnose omega
	#
	# assume hydrostatic balance
	# omega = -rho g w = -p g w / ( R tem ) = p w / tem * ( -g / R )
	#
	INPUT_W_NC=${INPUT_W_NC_LIST[$d]}
	INPUT_TEM_NC=${INPUT_TEM_NC_LIST[$d]}
	INPUT_PRES_NC=${INPUT_PRES_NC_LIST[$d]}
	#
        GRAV=9.80616  # following NICAM
        GASR=287.04   # following NICAM
	VAL=$( echo "scale=5; -${GRAV}/${GASR}" | bc )
	#
	NOTHING=0
	cd ${TEMP_DIR}	
	cdo -s -b 32 mul ${INPUT_PRES_NC} ${INPUT_W_NC} pw.nc || exit 1
	cdo -s -b 32 div pw.nc ${INPUT_TEM_NC} pwt.nc || exit 1
	cdo -s -b 32 mulc,${VAL} pwt.nc temp.nc || exit 1
	cdo -s setname,ms_omega temp.nc temp2.nc || exit 1
	cdo -s setattribute,ms_omega@units="Pa/s",ms_omega@long_name="pressure velocity diagnosed from hydrostatic balance" temp2.nc temp3.nc || exit 1
	mv temp3.nc ${OUTPUT_NC} || exit 1
	rm pw.nc pwt.nc temp.nc temp2.nc
	#
	cd - > /dev/null || exit 1
	#
	YMD_PREV=${YMD}
    done  # loop: d


    #YMD_PREV=-1
    # ws
    for(( d=0; $d<${#INPUT_U_NC_LIST[@]}; d=$d+1 )) ; do
	INPUT_U_NC=${INPUT_U_NC_LIST[$d]}
	INPUT_V_NC=${INPUT_V_NC_LIST[$d]}
	INPUT_REF_NC=${INPUT_U_NC}
	#
	TDEF_FILE=$( cdo -s ntime ${INPUT_REF_NC} )
	YMD_GRADS=$( grads_ctl.pl ${INPUT_REF_NC} TDEF 1 )
        YMD=$( date -u --date "${YMD_GRADS}" +%Y%m%d ) || exit 1
	#(( ${YMD} == ${YMD_PREV} )) && { echo "error: time interval less than 1-dy is not supported now" ; exit 1 ; }
	YEAR=${YMD:0:4}
        #
        #----- output data
        #
        # File name convention (YMD = first day)
        #   2004/ms_tem_${YMD}.nc
        #
	OUTPUT_NC_BASENAME=$( echo ${INPUT_REF_NC##*/} | sed -e "s|${VAR_REF}|ms_ws|" )
	[[ "${OUTPUT_NC_BASENAME}" = "ms_ws.nc" ]] && OUTPUT_NC_BASENAME=${VAR}_${YMD}.nc
        #OUTPUT_NC=$( readlink -m ${OUTPUT_DIR}/${VAR}/${YEAR}/${VAR}_${YMD}.nc )
        OUTPUT_NC=$( readlink -m ${OUTPUT_DIR}/${VAR}/${YEAR}/${OUTPUT_NC_BASENAME} )
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
        echo "${OUTPUT_NC_BASENAME}"

#	VAL=$( echo "scale=5; -${GRAV}/${GASR}" | bc )
	#
	NOTHING=0
	cd ${TEMP_DIR}
	cdo -s -b 32 sqr ${INPUT_U_NC} u2.nc || exit 1
	cdo -s -b 32 sqr ${INPUT_V_NC} v2.nc || exit 1
	cdo -s -b 32 add u2.nc v2.nc uv2.nc  || exit 1
	cdo -s -b 32 sqrt uv2.nc temp.nc     || exit 1
	cdo -s setname,ms_ws temp.nc temp2.nc || exit 1
	cdo -s setattribute,ms_ws@units="m/s",ms_ws@long_name="windspeed" temp2.nc temp3.nc || exit 1
	mv temp3.nc ${OUTPUT_NC} || exit 1
	rm u2.nc v2.nc uv2.nc temp.nc temp2.nc
	#
	cd - > /dev/null || exit 1
	#
	#YMD_PREV=${YMD}
    done  # loop: d


done  # loop: VAR

(( ${NOTHING} == 1 )) && echo "info: Nothing to do."
echo "$0 normally finished ($(date))."
echo
