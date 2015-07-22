#
# Example:
#   . common.sh 
#   create_temp
#   trap "finish zonal_mean.sh" 0
#
# Note: Do not edit common.sh. The variables should be overwritten by usr/*.sh
#

BIN_GRADS_CTL=grads_ctl.pl
BIN_DIFF_PATH=diff-path

DIR_NICAM=/home/kodama/NICAM_src/bin
BIN_NC2CTL=${DIR_NICAM}/nc2ctl
BIN_ROUGHEN=${DIR_NICAM}/roughen
BIN_Z2PRE=${DIR_NICAM}/z2pre
BIN_ZONAL_MEAN=zonal_mean

export LANG=en
export F_UFMTENDIAN="big"


## directly of control files of raw data
##DIR_RAW_CTL=../../data_1st/ctl
#DIR_RAW_CTL=../../data_1st/ctl_nc
#
#REF_CTL=$( ls ${DIR_RAW_CTL}/m*_*.ctl 2> /dev/null | head -n 1 )
#[ "${REF_CTL}" = "" ] && REF_CTL=$( ls ${DIR_RAW_CTL}/s*_*.ctl 2> /dev/null | head -n 1 )
#[ "${REF_CTL}" = "" ] && REF_CTL=$( ls ${DIR_RAW_CTL}/l*_*.ctl 2> /dev/null | head -n 1 )
#[ "${REF_CTL}" = "" ] && REF_CTL=$( ls ${DIR_RAW_CTL}/o*_*.ctl 2> /dev/null | head -n 1 )
#[ "${REF_CTL}" = "" ] && REF_CTL=$( ls ${DIR_RAW_CTL}/dfq_isccp2.ctl 2> /dev/null | head -n 1 )
#[ "${REF_CTL}" = "" ] && ( echo "error: no ctl file in ${DIR_RAW_CTL}" ; exit 1 )
#
#REF_NC=${REF_CTL%${REF_CTL##*/}}$( head -n 1 ${REF_CTL} | awk '{print $2}' | sed -e "s/^^//" | sed -e "s/%ch/$( grep CHSUB ${REF_CTL} | head -n 1 | awk '{print $4}' )/")
#[ ! -f ${REF_NC} -o "${REF_NC}" = "${REF_NC%.nc}" ] && REF_NC=""
#if [ "${REF_NC}" != "" ] ; then
#    OPT_NC="nc=${REF_NC}"
#else
#    OPT_NC=""
#fi

# native grid
#XDEF_NAT=$( ${BIN_GRADS_CTL} ctl=${REF_CTL} ${OPT_NC} key=XDEF target=NUM )
#YDEF_NAT=$( ${BIN_GRADS_CTL} ctl=${REF_CTL} ${OPT_NC} key=YDEF target=NUM )
#ZDEF_NAT=$( ${BIN_GRADS_CTL} ctl=${REF_CTL} ${OPT_NC} key=ZDEF target=NUM )
#ZDEF_ISCCP=49


# GrADS command and version
GRADS_CMD="grads"
GRADS_VER="2.0.a7.1"

BIN_GRADS_CTL=grads_ctl.pl
#BIN_GRADS_CTL=/cwork5/kodama/program/sh_lib/grads_ctl/dev/grads_ctl.pl


# stdout and stderr logs
if [ "${LOG_STDOUT}" = "" ] ; then
    TEMP=$( date +%Y%m%d_%H%M%S )
    LOG_STDOUT=log/stdout_${TEMP}
    LOG_STDERR=log/stderr_${TEMP}
fi

TEMP_DIR=""
ORG_DIR=$( pwd )
function create_temp()
{
    local TEMP
    for(( i=1; $i<=10; i=$i+1 )) ; do
        TEMP=$( date +%s )
        TEMP_DIR=temp_${TEMP}
        [ ! -d ${TEMP_DIR} ] && break
        sleep 1s
    done
    mkdir ${TEMP_DIR}
}

function finish()
{
    local SH=$1
    cd ${ORG_DIR}
    rm -r ${TEMP_DIR}
    echo "########## ${SH} finish ##########"
    echo ""
}


# convert ${TAG}/${HORIZONTAL}/${TIME} 
function conv_dir()
{
    local DIR_IN=$1
    local DIR=${DIR_IN}
    local CNTL=$2
    local TARGET=$( echo ${CNTL} | cut -d = -f 1 )
    local VALUE=$( echo ${CNTL} | cut -d = -f 2 )
    local TAG_LIST=( advanced isccp ll ml_plev ml_zlev ol sl )
    local TDEF_LIST=( tstep 1dy_mean monthly_mean )

    if [ "${TARGET}" = "XDEF" -a ${VALUE} = "ZMEAN" ] ; then
	for TAG in ${TAG_LIST[@]} ; do
#	  DIR=`echo ${DIR} | sed -e "s|${TAG}/[0-9][0-9]*x\([0-9][0-9]*\)/|${TAG}/zmean_\1/|"`
#	  DIR=`echo ${DIR} | sed -e "s|${TAG}/[0-9][0-9]*x\([0-9][0-9]*x[0-9][0-9]*\)/|${TAG}/zmean_\1/|"`
#
	  # 320x160x18   -> zmean_160x18
	  # 320x160      -> zmean_160
	  # 320x160_p850 -> zmean_160_p850
	  DIR=$( echo ${DIR} | sed -e "s|${TAG}/[0-9][0-9]*x|${TAG}/zmean_|" )
#	  continue
	done

    elif [ "${TARGET}" = "XYDEF" ] ; then
	for TAG in ${TAG_LIST[@]} ; do
	  DIR=$( echo ${DIR} | sed -e "s|${TAG}/[0-9][0-9]*x[0-9][0-9]*/|${TAG}/${VALUE}/|" )
	  DIR=$( echo ${DIR} | sed -e "s|${TAG}/[0-9][0-9]*x[0-9][0-9]*\(x[0-9][0-9]*\)/|${TAG}/${VALUE}\1/|" )
	done

    elif [ "${TARGET}" = "ZDEF" ] ; then
	for TAG in ${TAG_LIST[@]} ; do
	    DIR=$( echo ${DIR} | sed -e "s|${TAG}/\([0-9][0-9]*x[0-9][0-9]*\)\(x[0-9][0-9]*\)*/|${TAG}/\1x${VALUE}/|" )
	done

    elif [ "${TARGET}" = "ZLEV" ] ; then
	for TAG in ${TAG_LIST[@]} ; do
	    DIR=$( echo ${DIR} | sed -e "s|${TAG}/\([0-9][0-9]*x[0-9][0-9]*\)\(x[0-9][0-9]*\)*/|${TAG}/\1_p${VALUE}/|" )
	done

    elif [ "${TARGET}" = "TAG" ] ; then
	for TAG in ${TAG_LIST[@]} ; do
	    DIR=$( echo ${DIR} | sed -e "s|${TAG}/\([0-9][0-9]*x[0-9][0-9]*\(x[0-9][0-9]*\)\)*/|${VALUE}/\1/|" )
	done

    elif [ "${TARGET}" = "TDEF" ] ; then
#	for TAG in ${TAG_LIST[@]}
#	do
	    for TDEF in ${TDEF_LIST[@]} ; do
#	        DIR=`echo ${DIR} | sed -e "s|${TDEF}$|${VALUE}|"`
	        DIR=$( echo ${DIR} | sed -e "s|${TDEF}|${VALUE}|" )
	    done
#	done

    fi

    if [ "${DIR}" = "${DIR_IN}" ] ; then
	echo "error in conv_dir: " 1>&2
	echo "  DIR_IN and DIR_OUT are same: ${DIR_IN}" 1>&2
	exit 1
    fi

    echo ${DIR}
    return
}


function get_pdef()
{
    local PDEF_LEVELS=$1

    # NOTE: "echo" adds \n
    echo ${PDEF_LEVELS} | sed -e "s/[^,]//g" | wc | awk '{ print $3 }'
}

#
# resolve dependencies of variables
# 
# only display $VAR which both $VARS_CHILD and $VARS_PARENT contain.
#
function dep_var()
{
    local NUM_CHILD=$1
    shift
    for(( i=0; $i<${NUM_CHILD}; i=$i+1 )) ; do
        local VARS_CHILD=( ${VARS_CHILD[@]} $1 )
        shift
    done
    local NUM_PARENT=$1
    shift
    for(( i=0; $i<${NUM_PARENT}; i=$i+1 )) ; do
        local VARS_PARENT=( ${VARS_PARENT[@]} $1 )
        shift
    done

    for VAR in ${VARS_CHILD[@]} ; do
        for VAR2 in ${VARS_PARENT[@]} ; do
	    [ "${VAR}" = "${VAR2}" -o "${VAR2}" = "ALL" ] \
		&& echo ${VAR} && continue
        done
    done
    return
}

#
# expand sl, ml, ll, ol in ${VAR} to actual variables
#
function expand_vars()
{
    local NUM_VARS=$1
    local VARS
    shift
    for(( i=0; $i<${NUM_VARS}; i=$i+1 )) ; do
        VARS=( ${VARS[@]} $1 )
        shift
    done

    VARS_ISCCP=( $( ls ../../isccp/${XDEF_NAT}x${YDEF_NAT}x${ZDEF_ISCCP}/tstep 2>/dev/null) )
    VARS_LL=(    $( ls ../../ll/${XDEF_NAT}x${YDEF_NAT}/tstep                  2>/dev/null ) )
    VARS_ML=(    $( ls ../../ml_zlev/${XDEF_NAT}x${YDEF_NAT}x${ZDEF_NAT}/tstep 2>/dev/null ) \
	      ms_omega ms_z )
    VARS_OL=(    $( ls ../../ol/${XDEF_NAT}x${YDEF_NAT}/tstep                  2>/dev/null ) )
    VARS_SL=(    $( ls ../../sl/${XDEF_NAT}x${YDEF_NAT}/tstep                  2>/dev/null ) )
    VARS_ADV=( cloud_cape cosp mim rain_from_cloud pdf_5dy pdf_monthly )
    VARS_ALL=(   ${VARS_ISCCP[@]} ${VARS_LL[@]} ${VARS_ML[@]} ${VARS_OL[@]} ${VARS_SL[@]} \
	         ${VARS_ADV[@]} )

    local VARS_TEMP=()
    for VAR in ${VARS[@]} ; do
        if [ "${VAR}" = "sl" ] ; then
	    VARS_TEMP=( ${VARS_TEMP[@]} ${VARS_SL[@]} )
	elif [ "${VAR}" = "ml" ] ; then
	    VARS_TEMP=( ${VARS_TEMP[@]} ${VARS_ML[@]} )
	elif [ "${VAR}" = "ll" ] ; then
	    VARS_TEMP=( ${VARS_TEMP[@]} ${VARS_LL[@]} )
	elif [ "${VAR}" = "ol" ] ; then
	    VARS_TEMP=( ${VARS_TEMP[@]} ${VARS_OL[@]} )
	elif [ "${VAR}" = "isccp" ] ; then
	    VARS_TEMP=( ${VARS_TEMP[@]} ${VARS_ISCCP[@]} )
	elif [ "${VAR}" = "ADV" ] ; then
	    VARS_TEMP=( ${VARS_TEMP[@]} ${VARS_ADV[@]}  )
	elif [ "${VAR}" = "ALL" ] ; then
	    VARS_TEMP=( ${VARS_TEMP[@]} ${VARS_ALL[@]}  )
	else
	    VARS_TEMP=( ${VARS_TEMP[@]} ${VAR} )
	fi
    done
    echo ${VARS_TEMP[@]}
}

# for date command (for average/snapshot)
function period_2_incre()
{
    local PERIOD=$1
    PERIOD=$( echo ${PERIOD} | cut -d _ -f 1 \
	| sed -e "s/hr/ hours/" \
	| sed -e "s/dy/ days/" \
	)
    echo ${PERIOD}
}
# for date command (time loop)
function period_2_loop()
{
    local PERIOD=$1
    TEMP=$( echo ${PERIOD} | grep hr )
    if [ "${TEMP}" = "" ] ; then
	echo $( period_2_incre ${PERIOD} )
    else
	echo "1 days"  # files are gathered per day
    fi
}

# e.g. 20040101 -> 00:00z01jan2004
function time_2_grads()
{
    local TIME=$1
    export LANG=en
    date -u --date "${TIME}" +%H:%Mz%d%b%Y
}

#
# tstep -> 1hr_step or 6hr_mean or ...
#
function tstep_2_period()
{
    local CTL=$1
    local VAR=${CTL##*/}
    local VAR=${VAR%.ctl}
    local TDEF_INCRE_HR=$( grads_ctl.pl ctl=${CTL} key=TDEF target=STEP unit=HR | sed -e "s/HR$//" )
    local TDEF_INCRE_DY=$( grads_ctl.pl ctl=${CTL} key=TDEF target=STEP unit=DY | sed -e "s/DY$//" )
    if [ ${TDEF_INCRE_HR} -lt 24 ] ; then
	PERIOD="${TDEF_INCRE_HR}hr"
    else
	PERIOD="${TDEF_INCRE_DY}dy"
    fi
    local SA=$( echo ${VAR} | cut -b 2 )
    if [ "${SA}" = "a" -o "${VAR}" = "dfq_isccp2" ] ; then  # mean
	PERIOD="${PERIOD}_mean"
    elif [ "${SA}" = "s" -o "${SA}" = "l" ] ; then  # snapshot
	PERIOD="${PERIOD}_tstep"
    else
	echo "error: SA=${SA} is not supported"
	exit 1
    fi
    echo ${PERIOD}
}


#
#
#
function get_data()
{
    local CTL=$1
    local VAR=$2
    local TMIN=$3
    local TMAX=$4
    local OUTPUT=$5
    cat > ${TEMP_DIR}/temp.gs <<EOF
'reinit'
rc = gsfallow( 'on' )
'xopen ${CTL}'
'set gxout fwrite'
'set fwrite -be ${OUTPUT}'
'set undef -0.99900E+35'
xdef = qctlinfo( 1, "xdef", 1 )
ydef = qctlinfo( 1, "ydef", 1 )
zdef = qctlinfo( 1, "zdef", 1 )
say xdef
'set x 1 'xdef
'set y 1 'ydef
t = ${TMIN}
while( t <= ${TMAX} )
  say 't = ' % t
  'set t 't
  z = 1
  while( z <= zdef )
*    say '  z = ' % z
    'set z 'z
    'd ${VAR}'
    z = z + 1
  endwhile
  t = t + 1
endwhile
'disable fwrite'
'quit'
EOF
#	cat ${TEMP_DIR}/temp.gs
	grads -blc ${TEMP_DIR}/temp.gs > /dev/null
#	grads -blc ${TEMP_DIR}/temp.gs
	rm ${TEMP_DIR}/temp.gs
}
