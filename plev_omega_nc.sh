#!/bin/bash
# w, rho (or T) -> omega [Pa/s]
#
echo "########## $0 start ##########"
set -x
CNFID=$1       # CNFID (e.g. "def")
START_YMD=$2   # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$3   # YYYYMMDD (end+1 day of analysis period)
INOUT_DIR=$4   # input/output directory
PDEF_LEVELS=$5 # pressure levels separated by comma
VAR_W=$6       # variable name of w
VAR_RHO=$7     # variable name of rho or "none"
VAR_TEM=$8     # variable name of tem or "none"(optional)
OVERWRITE=$9   # overwrite option (optional)
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

NOTHING=1
#============================================================#
#
#  variable (=omega) loop
#
#============================================================#
for VAR in m${VAR_W:1:1}_omega ; do
    #
    #----- check whether output dir is write-protected
    #
    if [[ -f "${INOUT_DIR}/${VAR}/_locked" ]] ; then
        echo "info: ${INOUT_DIR} is locked."
        continue
    fi
    mkdir -p ${INOUT_DIR}/${VAR}/log || exit 1
    OUTPUT_CTL=${INOUT_DIR}/${VAR}/${VAR}.ctl
    #
    #----- check existence of input data
    #
    INPUT_W_CTL=$( readlink -e ${INOUT_DIR}/${VAR_W}/${VAR_W}.ctl ) \
	|| { echo "warning: ${INPUT_W_CTL} does not exist." ; continue ; }
    if [[ "${VAR_RHO}" != "none" ]] ; then
	INPUT_RHO_CTL=$( readlink -e ${INOUT_DIR}/${VAR_RHO}/${VAR_RHO}.ctl ) \
	    || { echo "warning: ${INPUT_ROH_CTL} does not exist." ; continue ; }
	INPUT_TEM_CTL=""
    else
	INPUT_RHO_CTL=""
	INPUT_TEM_CTL=$( readlink -e ${INOUT_DIR}/${VAR_TEM}/${VAR_TEM}.ctl ) \
	    || { echo "warning: ${INPUT_TEM_CTL} does not exist." ; continue ; }
    fi
    #
    #----- get number of grids for input/output
    #
    INPUT_W_CTL_META=$( ctl_meta ${INPUT_W_CTL} ) || exit 1

    DIMS=( $( grads_ctl.pl ${INPUT_W_CTL_META} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}
    TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
#    TDEF_START=$(     grads_ctl.pl ${INPUT_W_CTL_META} TDEF 1 ) || exit 1
#    TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_W_CTL} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
#    TDEF_INCRE_MN=$(  grads_ctl.pl ${INPUT_W_CTL} TDEF INC --unit MN  | sed -e "s/MN//"  ) || exit 1
    #
    PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1
#    PDEF_LIST=$( echo ${PDEF_LEVELS} | sed -e "s/,/ /"g )
#    let TDEF_FILE=60*60*24/TDEF_INCRE_SEC       # number of time step per file
#    let TDEF_SEC_FILE=TDEF_INCRE_SEC*TDEF_FILE  # time in second per file
    #
#    START_HMS=$( date -u --date "${TDEF_START}" +%H%M%S )
#    TMP_H=${START_HMS:0:2}
#    TMP_M=${START_HMS:2:2}
#    let TMP_MN=TMP_H*60+TMP_M
#    if [ "${START_HMS}" = "000000" ] ; then
#	echo "It is not implemented."
#	exit 1
#    fi

    #
    #----- generate control file (unified)
    #
    if [[ ! "${OVERWRITE}" =~ ^(dry-rm|rm)$ ]] ; then
	sed ${INPUT_W_CTL} -e "s|^DSET .*|DSET ^%ch.nc|" -e "/^CHSUB .*/d" -e "s/^${VAR_W}/${VAR}/" > ${OUTPUT_CTL}
	grep ^CHSUB ${INPUT_W_CTL} | sed -e "s|/${VAR_W}_|/${VAR}_|" -e "s|.000000||g" -e "s|-.*$||" >> ${OUTPUT_CTL}
    fi
    #
    # check existence of input data
    #
    TMIN=$( grads_time2t.sh ${INPUT_W_CTL_META} ${START_YMD} -gt ) || exit 1
    TMAX=$( grads_time2t.sh ${INPUT_W_CTL_META} ${ENDPP_YMD} -le ) || exit 1
    INPUT_W_DSET_LIST=( $( grads_ctl.pl ${INPUT_W_CTL} DSET "${TMIN}:${TMAX}" ) )
    INPUT_W_NC_LIST=()
    INPUT_ROH_NC_LIST=()
    for INPUT_W_DSET in ${INPUT_W_DSET_LIST[@]} ; do
	INPUT_W_NC=$( readlink -e ${INPUT_W_DSET/^/${INPUT_W_CTL%/*}\//} ) \
	    || { echo "error: ${INPUT_W_DSET/^/${INPUT_W_CTL%/*}\//} does not exist." ; exit 1 ; }
	INPUT_W_NC_LIST+=( ${INPUT_W_NC} )

	INPUT_TEM_NC=""
	INPUT_ROH_NC=""
	if [[ "${INPUT_TEM_CTL}" != "" ]] ; then
	    INPUT_TEM_NC=$( readlink -e ${INPUT_W_NC//${VAR_W}/${VAR_TEM}} ) \
		|| { echo "error: ${INPUT_W_NC//${VAR_W}/${VAR_TEM}} does not exist." ; exit 1 ; }
	    [[ "${INPUT_TEM_NC}" == "${INPUT_W_NC}" ]] \
		&& { echo "duplicate error" ; exit 1 ; }
	else
	    INPUT_ROH_NC=$( readlink -e ${INPUT_W_NC//${VAR_W}/${VAR_ROH}} ) \
		|| { echo "error: ${INPUT_W_NC//${VAR_W}/${VAR_ROH}} does not exist." ; exit 1 ; }
	    [[ "${INPUT_ROH_NC}" == "${INPUT_W_NC}" ]] \
		&& { echo "duplicate error" ; exit 1 ; }
	fi
	INPUT_TEM_NC_LIST+=( "${INPUT_TEM_NC}" )
	INPUT_ROH_NC_LIST+=( "${INPUT_ROH_NC}" )
    done

#cdo -b 32 add ms_tem/1950/ms_tem_19500101.nc ms_z/1950/ms_z_19500101.nc test.nc


echo "ok2"
exit 1
    #
    #========================================#
    #  date loop (for each file)
    #========================================#
    for(( d=1; ${d}<=${TDEF}; d=${d}+${TDEF_FILE} )) ; do
	#
        #----- set/proceed date -----#
        #
        if [ ${d} -eq 1 ] ; then
            DATE=$( date -u --date "${TDEF_START}" +%Y%m%d\ %H:%M:%S ) || exit 1
        else
            DATE=$( date -u --date "${DATE} ${TDEF_SEC_FILE} seconds" +%Y%m%d\ %H:%M:%S ) || exit 1
        fi
        YMD=${DATE:0:8}
        #
        [ ${YMD} -lt ${START_YMD} ] && continue
        [ ${YMD} -ge ${ENDPP_YMD} ] && break
        #
        YMDPP=$( date -u --date "${YMD} 1 day" +%Y%m%d ) || exit 1
        YEAR=${DATE:0:4} ; MONTH=${DATE:4:2} ; DAY=${DATE:6:2}
        #
        #----- output data
        #
        # File name convention
        #   2004/ms_tem_20040601.grd  (center of the date if incre > 1dy)
        #
	OUTPUT_DATA=${INOUT_DIR}/${VAR}/${YEAR}/${VAR}_${YMD}$.grd
        mkdir -p ${INOUT_DIR}/${VAR}/${YEAR} || exit 1
        #
        #----- output file exist?
        #
        if [ -f "${OUTPUT_DATA}" ] ; then
            SIZE_OUT=$( ls -lL ${OUTPUT_DATA} | awk '{ print $5 }' ) || exit 1
            SIZE_OUT_EXACT=$( echo 4*${XDEF}*${YDEF}*${PDEF}*${TDEF_FILE} | bc ) || exit 1
            if [   ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} -a "${OVERWRITE}" != "yes" \
                -a "${OVERWRITE}" != "dry-rm" -a "${OVERWRITE}" != "rm" ] ; then
                continue 1
            fi
            echo "Removing ${OUTPUT_DATA}."
            echo ""
            [ "${OVERWRITE}" = "dry-rm" ] && continue 1
            rm -f ${OUTPUT_DATA}
        fi
        [ "${OVERWRITE}" = "rm" -o "${OVERWRITE}" = "dry-rm" ] && exit
	#
	# (w, rho) or (w, tem) -> omega
	#
	NOTHING=0
        echo "YMD=${YMD}"
	TMIN=$( grads_time2t.sh ${INPUT_W_CTL} ${YMD}   -gt ) || exit 1
	TMAX=$( grads_time2t.sh ${INPUT_W_CTL} ${YMDPP} -le ) || exit 1
	#
        cd ${TEMP_DIR}
	cat > temp.gs <<EOF
'reinit'
EOF
	GRAV=9.80616  # following NICAM
	GASR=287.04   # following NICAM
	if [ "${INPUT_RHO_CTL}" != "" ] ; then
	    VAR_GRADS="(-${VAR_W}.1*${VAR_RHO}.2*${GRAV})"
	    cat >> temp.gs <<EOF
'xopen ../${INPUT_W_CTL}'
'xopen ../${INPUT_RHO_CTL}'
EOF
	else
	    VAR_GRADS="(-${VAR_W}.1*(lev*100)*${GRAV}/(${GASR}*${VAR_TEM}.2))"
	    cat >> temp.gs <<EOF
'xopen ../${INPUT_W_CTL}'
'xopen ../${INPUT_TEM_CTL}'
EOF
	fi

	cat >> temp.gs <<EOF
*'set gxout grfill'
'set gxout fwrite'
'set undef dfile'
'set fwrite -be ${VAR}_${YMD}.grd'

'set x 1 '${XDEF}
'set y 1 '${YDEF}

t = ${TMIN}
while( t <= ${TMAX} )
  'set t 't
  say 't=' % t
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
	grads -blc temp.gs || exit 1
	#
        mv ${VAR}_${YMD}.grd ../${INOUT_DIR}/${VAR}/${YEAR} || exit 1
	mv temp.gs ../${INOUT_DIR}/${VAR}/log/temp_${YMD}.gs
        cd - > /dev/null || exit 1

    done   # date loop

done  # variable loop

[ ${NOTHING} -eq 1 ] && echo "info: Nothing to do."
echo "$0 normally finished."
echo
