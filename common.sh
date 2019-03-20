#
# Example:
#   . common.sh 
#
# Note: Do not edit common.sh. The variables can be overwritten by usr/*.sh
#
export LANG=C
export F_UFMTENDIAN="big"
CNFID=${1:-def}   # CNFID ("def" by default)

#############################################################

DIR_NICAM=/home/kodama/NICAM_src/bin
BIN_NC2CTL=${DIR_NICAM}/nc2ctl
BIN_ROUGHEN=${DIR_NICAM}/roughen
BIN_Z2PRE=${DIR_NICAM}/z2pre

BIN_CDO=/home/kodama/bin/cdo

INPUT_TOP_RDIR=NOT_SPECIFIED
DCONV_TOP_RDIR=NOT_SPECIFIED

#
# Native (i.e. finest mesh) grid data information
#
XDEF_NAT=-1
YDEF_NAT=-1
#ZDEF_NAT=-1
ZDEF_ISCCP=-1
ZDEF_TYPE=ml_zlev


# default job parameters
FLAG_TSTEP_DERIVE=0
FLAG_TSTEP_REDUCE=0
FLAG_TSTEP_Z2PRE=0
FLAG_TSTEP_PLEVOMEGA=0
FLAG_TSTEP_PLEVZ=0
FLAG_TSTEP_ISCCP3CAT=0
FLAG_TSTEP_ZM=0
FLAG_MM_ZM=0

FLAG_KEEP_NC=0  # NetCDF -> NetCDF

OVERWRITE="no"
VERBOSE=0
INC_SUBVARS="yes"
#############################################################

. cnf/common.sh
if [ -f ./cnf/${CNFID}.sh ] ; then
    . ./cnf/${CNFID}.sh ${CNFID}
else
    echo "error in common.sh: ./cnf/${CNFID}.sh does not exist."
    exit 1
fi

XDEF_NAT5=$( printf "%05d" ${XDEF_NAT} )
YDEF_NAT5=$( printf "%05d" ${YDEF_NAT} )


VERBOSE_OPT=""
[ ${VERBOSE} -ge 1 ] && VERBOSE_OPT="-v"
[ ${VERBOSE} -ge 2 ] && VERBOSE_OPT="-v -v"

# convert ${TAG}/${HORIZONTAL}/${TIME} 
function conv_dir()
{
    local DIR_IN=$1
    local DIR=${DIR_IN}
    local CNTL=$2
    local TARGET=$( echo ${CNTL} | cut -d = -f 1 )
    local VALUE=$( echo ${CNTL} | cut -d = -f 2 )
    local TDEF_LIST=( tstep 1dy_mean monthly_mean )
    local KEY_LIST=( isccp ll ml_zlev ml_plev ol sl )

    if [[ "${TARGET}" = "XDEF" && ${VALUE} = "ZMEAN" ]] ; then
	for KEY in ${KEY_LIST[@]} ; do
	    # 320x160x18   -> zmean_160x18
	    # 320x160      -> zmean_160
	    # 320x160_p850 -> zmean_160_p850
	    DIR=$( echo ${DIR} | sed -e "s|${KEY}/[0-9][0-9]*x|${KEY}/zmean_|" )
	done

    elif [[ "${TARGET}" = "XDEF" && ${VALUE} = "MMZMEAN" ]] ; then
	for KEY in ${KEY_LIST[@]} ; do
	    DIR=$( echo ${DIR} | sed -e "s|${KEY}/[0-9][0-9]*x|${KEY}/mm_zmean_|" )
	done

    elif [[ "${TARGET}" = "XYDEF" ]] ; then
	for KEY in ${KEY_LIST[@]} ; do
	  DIR=$( echo ${DIR} | sed -e "s|${KEY}/[0-9][0-9]*x[0-9][0-9]*/|${KEY}/${VALUE}/|" )
	  DIR=$( echo ${DIR} | sed -e "s|${KEY}/[0-9][0-9]*x[0-9][0-9]*\(x[0-9][0-9]*\)/|${KEY}/${VALUE}\1/|" )
	  DIR=$( echo ${DIR} | sed -e "s|${KEY}/[0-9][0-9]*x[0-9][0-9]*\(_p[0-9][0-9]*\)/|${KEY}/${VALUE}\1/|" )
	done

    elif [[ "${TARGET}" = "ZDEF" ]] ; then
	for KEY in ${KEY_LIST[@]} ; do
	    DIR=$( echo ${DIR} | sed -e "s|${KEY}/\([0-9][0-9]*x[0-9][0-9]*\)\(x[0-9][0-9]*\)*/|${KEY}/\1x${VALUE}/|" )
	done

    elif [[ "${TARGET}" = "ZLEV" ]] ; then
	for KEY in ${KEY_LIST[@]} ; do
	    DIR=$( echo ${DIR} | sed -e "s|${KEY}/\([0-9][0-9]*x[0-9][0-9]*\)\(x[0-9][0-9]*\)*/|${KEY}/\1_p${VALUE}/|" )
	done

    elif [[ "${TARGET}" = "ZID" ]] ; then
	for KEY in ${KEY_LIST[@]} ; do
	    DIR=$( echo ${DIR} | sed -e "s|${KEY}/\([0-9][0-9]*x[0-9][0-9]*\)\(x[0-9][0-9]*\)*/|${KEY}/\1_${VALUE}/|" )
	done

    elif [[ "${TARGET}" = "TAG" ]] ; then
	for KEY in ${KEY_LIST[@]} ; do
	    DIR=$( echo ${DIR} | sed -e "s|${KEY}/\([0-9][0-9]*x[0-9][0-9]*\(x[0-9][0-9]*\)\)*/|${VALUE}/\1/|" )
	done

    elif [[ "${TARGET}" = "TDEF" ]] ; then
	for TDEF in ${TDEF_LIST[@]} ; do
	    DIR=$( echo ${DIR} | sed -e "s|${TDEF}|${VALUE}|" )
	done
    fi

    if [[ "${DIR}" = "${DIR_IN}" ]] ; then
	echo "error in conv_dir: " 1>&2
	echo "  DIR_IN and DIR_OUT are same: ${DIR_IN}" 1>&2
	exit 1
    fi

    echo ${DIR}
    return 0
}


function pid2plevels()
{
    local PID=$1
    local PDEF_LEVELS=${PID}  # default

    # for CMIP6
    [[ "${PID}" = "plev19" ]] && PDEF_LEVELS="1000,925,850,700,600,500,400,300,250,200,150,100,70,50,30,20,10,5,1"

    echo ${PDEF_LEVELS}
}


function get_pdef()
{
    local PDEF_LEVELS=$1
    PDEF_LEVELS=$( pid2plevels ${PDEF_LEVELS} )

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
    return 0
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

    

#    VARS_ISCCP=( $( ls ../../isccp/${XDEF_NAT}x${YDEF_NAT}x${ZDEF_ISCCP}/tstep 2>/dev/null) )
#    VARS_LL=(    $( ls ../../ll/${XDEF_NAT}x${YDEF_NAT}/tstep                  2>/dev/null ) )
#    VARS_ML=(    $( ls ../../${ZDEF_TYPE}/${XDEF_NAT}x${YDEF_NAT}x*/tstep 2>/dev/null ) \
#	ms_omega ms_z )
#    VARS_OL=(    $( ls ../../ol/${XDEF_NAT}x${YDEF_NAT}/tstep                  2>/dev/null ) )
#    VARS_SL=(    $( ls ../../sl/${XDEF_NAT}x${YDEF_NAT}/tstep                  2>/dev/null ) )
    VARS_ISCCP=( $( ls ${DCONV_TOP_RDIR}/isccp/${XDEF_NAT5}x${YDEF_NAT5}x${ZDEF_ISCCP}/tstep 2>/dev/null) )
    VARS_LL=(    $( ls ${DCONV_TOP_RDIR}/ll/${XDEF_NAT5}x${YDEF_NAT5}/tstep                  2>/dev/null ) )
    VARS_ML=(    $( ls ${DCONV_TOP_RDIR}/${ZDEF_TYPE}/${XDEF_NAT5}x${YDEF_NAT5}x*/tstep 2>/dev/null ) \
	            ms_omega ms_z ms_ws )
    VARS_OL=(    $( ls ${DCONV_TOP_RDIR}/ol/${XDEF_NAT5}x${YDEF_NAT5}/tstep                  2>/dev/null ) )
    VARS_SL=(    $( ls ${DCONV_TOP_RDIR}/sl/${XDEF_NAT5}x${YDEF_NAT5}/tstep                  2>/dev/null ) \
	            ss_ws10m sa_ws10m )
#    VARS_ADV=( cloud_cape cosp mim rain_from_cloud pdf_5dy pdf_monthly )
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
#	elif [ "${VAR}" = "ADV" ] ; then
#	    VARS_TEMP=( ${VARS_TEMP[@]} ${VARS_ADV[@]}  )
	elif [ "${VAR}" = "ALL" -o "${VAR}" = "all" ] ; then
	    VARS_TEMP=( ${VARS_TEMP[@]} ${VARS_ALL[@]}  )
	else
	    VARS_TEMP=( ${VARS_TEMP[@]} ${VAR} )
	fi
    done
    VARS_TEMP=( $( IFS=$'\n' ; echo "${VARS_TEMP[*]}" | sort | uniq ; ) )  # delete duplicate
    echo ${VARS_TEMP[@]}
}

# search for control file for light metadata if possible
function ctl_meta()
{
    local CTL=$1
    [[ -f ${CTL%.ctl}_meta.ctl ]] && CTL=${CTL%.ctl}_meta.ctl
    [[ -f ${CTL%/*}/meta/${CTL##*/} ]] && CTL=${CTL%/*}/meta/${CTL##*/}
    echo ${CTL}
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
    [[ -f ${CTL%.ctl}_meta.ctl ]] && CTL=${CTL%.ctl}_meta.ctl
    [[ -f ${CTL%/*}/meta/${CTL##*/} ]] && CTL=${CTL%/*}/meta/${CTL##*/}
    local TDEF_INCRE_HR=$( grads_ctl.pl ${CTL} TDEF INC --unit HR | sed -e "s/HR$//" )
    local TDEF_INCRE_DY=$( grads_ctl.pl ${CTL} TDEF INC --unit DY | sed -e "s/DY$//" )

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

