#!/bin/sh
# w, rho (or T) -> omega [Pa/s]
#
. ./common.sh || exit 1

echo "########## $0 start ##########"
set -x
START_YMD=$1   # YYYYMMDD (start day of analysis period)
ENDPP_YMD=$2   # YYYYMMDD (end+1 day of analysis period)
INOUT_DIR=$3   # input/output directory
PDEF_LEVELS=$4 # pressure levels separated by comma
VAR_W=$5       # variable name of w
VAR_RHO=$6     # variable name of rho or "none"
VAR_TEM=$7     # variable name of tem or "none"(optional)
OVERWRITE=$8   # overwrite option (optional)
set +x
echo "##########"

create_temp || exit 1
TEMP_DIR=${BASH_COMMON_TEMP_DIR}
trap "finish" 0

if [   "${OVERWRITE}" != ""                                 \
    -a "${OVERWRITE}" != "yes"    -a "${OVERWRITE}" != "no" \
    -a "${OVERWRITE}" != "dry-rm" -a "${OVERWRITE}" != "rm" ] ; then
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
    if [ -f "${INOUT_DIR}/${VAR}/_locked" ] ; then
        echo "info: ${INOUT_DIR} is locked."
        continue
    fi
    #
    #----- check existence of output data
    #
    OUTPUT_CTL=${INOUT_DIR}/${VAR}/${VAR}.ctl
    if [ -f "${OUTPUT_CTL}" ] ; then
        FLAG=( $( exist_data.sh ${OUTPUT_CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
        if [ "${FLAG[0]}" = "ok" ] ; then
            echo "info: Output data already exist."
            continue
        fi
    fi
    #
    #----- check existence of input data
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
	if [ ! -f "${CTL}" ] ; then
	    echo "warning: ${CTL} does not exist."
	    continue 2
	fi
	FLAG=( $( exist_data.sh ${CTL} -ymd "(${START_YMD}:${ENDPP_YMD}]" ) ) || exit 1
	if [ "${FLAG[0]}" != "ok" ] ; then
	    echo "warning: All or part of data does not exist (CTL=${CTL})."
	    continue 2
	fi
    done
    #
    #----- get number of grids for input/output
    #
    DIMS=( $( grads_ctl.pl ${INPUT_W_CTL} DIMS NUM ) ) || exit 1
    XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]}
    TDEF=${DIMS[3]} ; EDEF=${DIMS[4]}
    TDEF_START=$(     grads_ctl.pl ${INPUT_W_CTL} TDEF 1 ) || exit 1
    TDEF_INCRE_SEC=$( grads_ctl.pl ${INPUT_W_CTL} TDEF INC --unit SEC | sed -e "s/SEC//" ) || exit 1
    TDEF_INCRE_MN=$(  grads_ctl.pl ${INPUT_W_CTL} TDEF INC --unit MN  | sed -e "s/MN//"  ) || exit 1
    #
    PDEF=$( get_pdef ${PDEF_LEVELS} ) || exit 1
    PDEF_LIST=$( echo ${PDEF_LEVELS} | sed -e "s/,/ /"g )
    let TDEF_FILE=60*60*24/TDEF_INCRE_SEC       # number of time step per file
    let TDEF_SEC_FILE=TDEF_INCRE_SEC*TDEF_FILE  # time in second per file
    #
    #----- generate control file (unified)
    #
    mkdir -p ${INOUT_DIR}/${VAR}/log || exit 1
    grads_ctl.pl ${INPUT_W_CTL} > ${OUTPUT_CTL}.tmp1 || exit 1
    #
    rm -f ${OUTPUT_CTL}.chsub
    DATE=$( date -u --date "${TDEF_START}" +%Y%m%d\ %H:%M:%S ) || exit 1  # YYYYMMDD HH:MM:SS
    echo "CHSUB  1  ${TDEF_FILE}  ${DATE:0:4}/${VAR}_${DATE:0:8}" >> ${OUTPUT_CTL}.chsub
    for(( d=1+${TDEF_FILE}; ${d}<=${TDEF}; d=${d}+${TDEF_FILE} )) ; do
        let CHSUB_MAX=d+TDEF_FILE-1
        DATE=$( date -u --date "${DATE} ${TDEF_SEC_FILE} seconds" +%Y%m%d\ %H:%M:%S ) || exit 1
        echo "CHSUB  ${d}  ${CHSUB_MAX}  ${DATE:0:4}/${VAR}_${DATE:0:8}" >> ${OUTPUT_CTL}.chsub
    done
    sed ${OUTPUT_CTL}.tmp1 \
        -e "s|^DSET .*$|DSET \^%ch.grd|" \
	-e "/^CHSUB .*/d"  \
	-e "s/TEMPLATE//ig" \
        -e "s/^OPTIONS .*$/OPTIONS TEMPLATE BIG_ENDIAN/i" \
	-e "s/^UNDEF .*$/UNDEF -0.99900E+35/i"  \
	-e "/^ZDEF/,/^TDEF/{" \
	-e "/^\(ZDEF\|TDEF\)/!D" \
	-e "}" \
	-e "s/^ZDEF .*/ZDEF  ${PDEF}  LEVELS  ${PDEF_LIST}/" \
        -e "s/^TDEF .*$/TDEF    ${TDEF}  LINEAR  ${TDEF_START}  ${TDEF_INCRE_MN}mn/" \
	-e "s/^${VAR_W} /${VAR} /" \
	| sed -e "s/m\/s/Pa\/s/" \
	> ${OUTPUT_CTL}.tmp || exit 1
    sed -e "/^DSET/q" ${OUTPUT_CTL}.tmp    > ${OUTPUT_CTL} || exit 1
    cat ${OUTPUT_CTL}.chsub               >> ${OUTPUT_CTL} || exit 1
    sed -e "0,/^DSET/d" ${OUTPUT_CTL}.tmp >> ${OUTPUT_CTL} || exit 1
    rm ${OUTPUT_CTL}.tmp ${OUTPUT_CTL}.tmp1 ${OUTPUT_CTL}.chsub
#    cat ${OUTPUT_CTL}
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
