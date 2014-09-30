#!/bin/sh
# create link for raw data
#
# Before execution, check
# -VAR="?l_*" and "dfq_isccp2" is snapshot or mean
#

# do not delete existing symbolic links
USE_OLD=1

#
# directry of control files
#
#EXT=grd
EXT=nc

#INPUT_DIR_CTL=../../data_1st/ctl_nc

i=0
INPUT_DIR_CTL_LIST=() ; INPUT_ML_LIST=()

#----------------------------------------#

INPUT_DIR_CTL_LIST[$i]=../../data_2nd/output/ctl_nc/00144x00072.zorg.torg
INPUT_ML_LIST[$i]=ml_zlev
let i++

INPUT_DIR_CTL_LIST[$i]=../../data_2nd/output/ctl_nc/00288x00145.zorg.torg
INPUT_ML_LIST[$i]=ml_zlev
let i++

INPUT_DIR_CTL_LIST[$i]=../../data_2nd/output/ctl_nc/00360x00181.zorg.torg
INPUT_ML_LIST[$i]=ml_zlev
let i++

INPUT_DIR_CTL_LIST[$i]=../../data_2nd/output/ctl_nc/00144x00072.p37.torg
INPUT_ML_LIST[$i]=ml_plev
let i++

INPUT_DIR_CTL_LIST[$i]=../../data_2nd/output/ctl_nc/00288x00145.p37.torg
INPUT_ML_LIST[$i]=ml_plev
let i++

INPUT_DIR_CTL_LIST[$i]=../../data_2nd/output/ctl_nc/00360x00181.p26.torg
INPUT_ML_LIST[$i]=ml_plev
let i++

#----------------------------------------#

BIN_GRADS_CTL=grads_ctl.pl
#BIN_GRADS_CTL=/cwork5/kodama/program/sh_lib/grads_ctl/dev/grads_ctl.pl

BIN_DIFF_PATH=diff-path
#BIN_DIFF_PATH=/cwork5/kodama/program/sh_lib/diff-path/dev/diff-path


#----------------------------------------#
CHSUB_BREAK_LIST=()
#for INPUT_DIR_CTL in ${INPUT_DIR_CTL_LIST[@]} ; do
for(( i=0; $i<${#INPUT_DIR_CTL_LIST[@]}; i=$i+1 )) ; do
    INPUT_DIR_CTL=${INPUT_DIR_CTL_LIST[$i]}
    INPUT_ML=${INPUT_ML_LIST[$i]}
    echo ${INPUT_DIR_CTL}

    VAR_LIST=( $( ls ${INPUT_DIR_CTL}/*.ctl | sed -e "s|.ctl$||g" -e "s|^.*/||g" ) ) || exit 1
    for VAR in ${VAR_LIST[@]} ; do
	echo "  ${VAR}"
        #
        # detrmine type of the variable
        #
	TAG_TEMP=${VAR:0:1}
	if [ "${TAG_TEMP}" = "s" ] ; then
	    TAG="sl"
	elif [ "${TAG_TEMP}" = "m" ] ; then
#	    TAG="ml_zlev"
	    TAG=${INPUT_ML}
	elif [ "${TAG_TEMP}" = "o" ] ; then
	    TAG="ol"
	elif [ "${TAG_TEMP}" = "l" ] ; then
	    TAG="ll"
	elif [ "${VAR}" = "dfq_isccp2" ] ; then
	    TAG="isccp"
	else
	    echo "${VAR} is not supported"
	    echo "skip!"
	    continue
	fi

	INPUT_CTL=${INPUT_DIR_CTL}/${VAR}.ctl
	INPUT_DATA_TEMPLATE=$( grep ^DSET ${INPUT_CTL} | sed -e "s|^DSET *^||i" ) || exit 1
	INPUT_DATA_TEMPLATE=${INPUT_DIR_CTL}/${INPUT_DATA_TEMPLATE}

	CHSUB_LIST=( $( grep "^CHSUB" ${INPUT_CTL} | awk '{ print $4 }' ) ) || exit 1
	OPT_NC=""
	if [ "${EXT}" = "nc" ] ; then
	    INPUT_DATA=$( echo ${INPUT_DATA_TEMPLATE} | sed -e "s|%ch|${CHSUB_LIST[0]}|g" ) || exit 1
	    OPT_NC="nc=${INPUT_DATA}"
	fi

	XDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=XDEF target=NUM ) || exit 1
	YDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=YDEF target=NUM ) || exit 1
	ZDEF=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=ZDEF target=NUM ) || exit 1
	TDEF_INCRE_HR=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=STEP unit=HR | sed -e "s|HR$||" ) || exit 1
	TDEF_INCRE_DY=$( ${BIN_GRADS_CTL} ctl=${INPUT_CTL} ${OPT_NC} key=TDEF target=STEP unit=DY | sed -e "s|DY$||" ) || exit 1
	if [ ${TDEF_INCRE_HR} -lt 24 ] ; then
	    PERIOD="${TDEF_INCRE_HR}hr"
	else
	    PERIOD="${TDEF_INCRE_DY}dy"
	fi
        #
	SA=${VAR:1:1}
	if [ "${SA}" = "a" -o "${VAR}" = "dfq_isccp2" ] ; then  # mean
	    PERIOD="${PERIOD}_mean"
	elif [ "${SA}" = "s" -o "${SA}" = "l" ] ; then  # snapshot
	    PERIOD="${PERIOD}_tstep"
	else
	    echo "error: SA=${SA} is not supported"
	    exit 1
	fi
        #
	[ "${ZDEF}" = "0" ] && ZDEF=1
	if [ "${ZDEF}" = "1" -o "${TAG}" = "ll" ] ; then
	    OUTPUT_DIR=../${TAG}/${XDEF}x${YDEF}/tstep/${VAR}
	    OUTPUT_DIR2=../${TAG}/${XDEF}x${YDEF}/${PERIOD}/${VAR}
	else
	    OUTPUT_DIR=../${TAG}/${XDEF}x${YDEF}x${ZDEF}/tstep/${VAR}
	    OUTPUT_DIR2=../${TAG}/${XDEF}x${YDEF}x${ZDEF}/${PERIOD}/${VAR}
	fi 
	mkdir -p ${OUTPUT_DIR} ${OUTPUT_DIR2}
	OUTPUT_CTL=${OUTPUT_DIR}/${VAR}.ctl
	OUTPUT_CTL2=${OUTPUT_DIR2}/${VAR}.ctl
	touch ${OUTPUT_DIR}/_locked    # raw data flag
	touch ${OUTPUT_DIR2}/_locked   # raw data flag

	sed ${INPUT_CTL} -e "s|^DSET .*$|DSET ^%ch/${VAR}.${EXT}|i" \
	    > ${OUTPUT_CTL2} || exit 1
	cp ${OUTPUT_CTL2} ${OUTPUT_CTL}


	for CHSUB in ${CHSUB_LIST[@]} ; do
#	    echo ${CHSUB}

	    INPUT_DATA=$( echo ${INPUT_DATA_TEMPLATE} | sed -e "s|%ch|${CHSUB}|g" ) || exit 1
	    if [ ! -f ${INPUT_DATA} ] ; then
		echo "    info: break at ${CHSUB}"
		CHSUB_BREAK_LIST=( ${CHSUB_BREAK_LIST[@]} ${CHSUB} )
		break
	    fi
	    INPUT_DIR_DATA=${INPUT_DATA%${INPUT_DATA##*/}}

	    mkdir -p ${OUTPUT_DIR}/${CHSUB}
	    #echo "${OUTPUT_DIR}/${CHSUB}/${VAR}.${EXT}"
	    if [ -L ${OUTPUT_DIR}/${CHSUB}/${VAR}.${EXT} -a -L ${OUTPUT_DIR2}/${CHSUB}/${VAR}.${EXT} -a ${USE_OLD} -eq 1 ] ; then
		continue
	    fi

            rm -f ${OUTPUT_DIR}/${CHSUB}/${VAR}.${EXT}
	    OUTPUT_LINK_DATA=$( ${BIN_DIFF_PATH} ${OUTPUT_DIR}/${CHSUB} ${INPUT_DIR_DATA} ) || exit 1
	    OUTPUT_LINK_DATA=${OUTPUT_LINK_DATA}/${VAR}.${EXT}
	    ln -s ${OUTPUT_LINK_DATA} ${OUTPUT_DIR}/${CHSUB}/${VAR}.${EXT} || exit 1
	    
	    mkdir -p ${OUTPUT_DIR2}/${CHSUB}
            rm -f ${OUTPUT_DIR2}/${CHSUB}/${VAR}.${EXT}
	    OUTPUT_LINK_DATA=$( ${BIN_DIFF_PATH} ${OUTPUT_DIR2}/${CHSUB} ${INPUT_DIR_DATA} ) || exit 1
	    OUTPUT_LINK_DATA=${OUTPUT_LINK_DATA}/${VAR}.${EXT}
	    ln -s ${OUTPUT_LINK_DATA} ${OUTPUT_DIR2}/${CHSUB}/${VAR}.${EXT} || exit 1
	done

    done

done

if [ ${#CHSUB_BREAK_LIST[*]} -gt 0 ] ; then
    IFS=$'\n'
    CHSUB_BREAK_MIN=$( echo "${CHSUB_BREAK_LIST[*]}" | sort | head -n 1 )
    echo ""
    echo "  info: minimum break date is ${CHSUB_BREAK_MIN}"
    echo ""
fi

echo "link.sh normally finishes"
