#!/bin/sh
# create link for NICAM data
#
# Before execution, check
# -VAR="?l_*" and "dfq_isccp2" is snapshot or mean
#
. ./common.sh
. ./usr/cnf_link.sh

#----------------------------------------#
CHSUB_BREAK_LIST=()
for(( i=0; $i<${#INPUT_DIR_CTL_LIST[@]}; i=$i+1 )) ; do
    INPUT_DIR_CTL=${INPUT_DIR_CTL_LIST[$i]}
    INPUT_ML=${INPUT_ML_LIST[$i]}
    INPUT_TIME=${INPUT_TIME_LIST[$i]}
    EXT=${EXT_LIST[$i]}
    echo ${INPUT_DIR_CTL}

    if [ "${SEP_DIR_LIST[$i]}" = "1"  ] ; then
	TMP_LIST=( $( ls ${INPUT_DIR_CTL}/*/*.ctl ) ) || exit 1
    else
	TMP_LIST=( $( ls ${INPUT_DIR_CTL}/*.ctl ) ) || exit 1
    fi
    for TMP in ${TMP_LIST[@]} ; do
	VDEF=$( grads_ctl.pl ${TMP} VARS NUM ) || exit 1
	if [ ${VDEF} = 1 ] ; then
	    INPUT_CTL_LIST[${#INPUT_CTL_LIST[@]}]=${TMP}
	    VAR_LIST[${#VAR_LIST[@]}]=$( echo "${TMP}" | sed -e "s|.ctl$||g" -e "s|^.*/||g" ) || exit 1
	else
	    SUBVAR_LIST=( $( grads_ctl.pl ${TMP} VARS ALL ) ) || exit 1
	    for SUBVAR in ${SUBVAR_LIST[@]} ; do
		INPUT_CTL_LIST[${#INPUT_CTL_LIST[@]}]=${TMP}
		VAR_LIST[${#VAR_LIST[@]}]=${SUBVAR}
	    done
	fi
    done

    for(( j=0; $j<${#VAR_LIST[@]}; j=$j+1 )) ; do
	VAR=${VAR_LIST[$j]}
	INPUT_CTL=${INPUT_CTL_LIST[$j]}
	echo "  ${VAR}"
        #
        # detrmine type of the variable
        #
	TAG_TEMP=${VAR:0:1}
	if [ "${TAG_TEMP}" = "s" ] ; then
	    TAG="sl"
	elif [ "${TAG_TEMP}" = "m" ] ; then
	    TAG=${INPUT_ML}
	elif [ "${TAG_TEMP}" = "o" ] ; then
	    TAG="ol"
	elif [ "${TAG_TEMP}" = "l" ] ; then
	    TAG="ll"
	elif [ "${VAR}" = "dfq_isccp2" ] ; then
	    TAG="isccp"
	else
	    echo "${VAR} is not supported."
	    echo "skip!"
	    continue
	fi
	INPUT_DIR_CTL_CHILD=${INPUT_CTL%/*}
	INPUT_DATA_TEMPLATE=$( grep ^DSET ${INPUT_CTL} | sed -e "s|^DSET *^||i" ) || exit 1
	INPUT_DATA_TEMPLATE=${INPUT_DIR_CTL_CHILD}/${INPUT_DATA_TEMPLATE}
	INPUT_DATA_TEMPLATE_HEAD=$( echo "${INPUT_DATA_TEMPLATE}" | sed -e "s|%ch.*$||" )
	INPUT_DATA_TEMPLATE_TAIL=$( echo "${INPUT_DATA_TEMPLATE}" | sed -e "s|^.*%ch||" )

	# dimension
	CHSUB_LIST=( $( grep "^CHSUB" ${INPUT_CTL} | awk '{ print $4 }' ) ) || exit 1
        DIMS=( $( grads_ctl.pl ${INPUT_CTL} DIMS NUM ) ) || exit 1
	XDEF=${DIMS[0]} ; YDEF=${DIMS[1]} ; ZDEF=${DIMS[2]} ; 
	[ "${ZDEF}" = "0" ] && ZDEF=1

	if [ "${INPUT_TIME}" = "monthly_mean" ] ; then
	    PERIOD="monthly_mean"
	else
	    TDEF_INCRE_HR=$( grads_ctl.pl ${INPUT_CTL} TDEF INC --unit HR | sed -e "s|HR$||" ) || exit 1
	    TDEF_INCRE_DY=$( grads_ctl.pl ${INPUT_CTL} TDEF INC --unit DY | sed -e "s|DY$||" ) || exit 1
	    if [ ${TDEF_INCRE_HR} -lt 24 ] ; then
		PERIOD="${TDEF_INCRE_HR}hr"
	    else
		PERIOD="${TDEF_INCRE_DY}dy"
	    fi
	    SA=${VAR:1:1}
	    if [ "${SA}" = "a" -o "${VAR}" = "dfq_isccp2" ] ; then  # mean
		PERIOD="${PERIOD}_mean"
	    elif [ "${SA}" = "s" -o "${SA}" = "l" ] ; then  # snapshot
		PERIOD="${PERIOD}_tstep"
	    else
		echo "error in $0: SA=${SA} is not supported."
		exit 1
	    fi
	fi

	if [ "${ZDEF}" = "1" -o "${TAG}" = "ll" ] ; then
	    OUTPUT_DIR=../../${TAG}/${XDEF}x${YDEF}/${PERIOD}/${VAR}
	else
	    OUTPUT_DIR=../../${TAG}/${XDEF}x${YDEF}x${ZDEF}/${PERIOD}/${VAR}
	fi 
	mkdir -p ${OUTPUT_DIR}
	touch ${OUTPUT_DIR}/_locked    # raw data flag

	if [ "${INPUT_TIME}" = "tstep" ] ; then
	    OUTPUT_DIR2=$( echo "${OUTPUT_DIR}" | sed -e "s|/${PERIOD}/|/tstep/|" )
	    mkdir -p ${OUTPUT_DIR2%/*}
	    rm -f ${OUTPUT_DIR2}
	    ln -s ../${PERIOD}/${VAR} ${OUTPUT_DIR2}
	fi

	if [ ${#CHSUB_LIST[@]} -gt 0 ] ; then
	    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}.ctl
	    sed ${INPUT_CTL} -e "s|^DSET .*$|DSET ^%ch/${VAR}.${EXT}|i" \
		> ${OUTPUT_CTL} || exit 1
	    
	    # assuming that CHSUBs are same directory structure with each other.
	    OUTPUT_DATA_TEMPLATE=""
	    for CHSUB in ${CHSUB_LIST[@]} ; do
		if [ -L ${OUTPUT_DIR}/${CHSUB}/${VAR}.${EXT} ] ; then
		    [ ${USE_OLD} -eq 1 ] && continue
		    rm -f ${OUTPUT_DIR}/${CHSUB}/${VAR}.${EXT}
		fi
		INPUT_DATA=${INPUT_DATA_TEMPLATE_HEAD}${CHSUB}${INPUT_DATA_TEMPLATE_TAIL}
		if [ ! -f ${INPUT_DATA} ] ; then
		    echo "    info: break at ${CHSUB}."
		    CHSUB_BREAK_LIST=( ${CHSUB_BREAK_LIST[@]} ${CHSUB} )
		    break
		fi
		mkdir -p ${OUTPUT_DIR}/${CHSUB}

		# just for once
		if [ "${OUTPUT_DATA_TEMPLATE}" = "" ] ; then
		    INPUT_DIR_DATA=${INPUT_DATA%/*}
		    DIFF_DIR=$( diff-path ${OUTPUT_DIR}/${CHSUB} ${INPUT_DIR_DATA} ) || exit 1
		    DIFF_DIR=$( echo ${DIFF_DIR} | sed -e "s|${CHSUB}/|%ch/|g" )
		    OUTPUT_DATA_TEMPLATE=${DIFF_DIR}/${VAR}.${EXT}
		    OUTPUT_DATA_TEMPLATE_HEAD=$( echo "${OUTPUT_DATA_TEMPLATE}" | sed -e "s|%ch.*$||" )
		    OUTPUT_DATA_TEMPLATE_TAIL=$( echo "${OUTPUT_DATA_TEMPLATE}" | sed -e "s|^.*%ch||" )
		fi

		ln -s ${OUTPUT_DATA_TEMPLATE_HEAD}${CHSUB}${OUTPUT_DATA_TEMPLATE_TAIL} ${OUTPUT_DIR}/${CHSUB}/${VAR}.${EXT} || exit 1
	    done
	else
	    # just link all files/dirs
	    LINK_DIR=$( diff-path ${OUTPUT_DIR} ${INPUT_DIR_CTL_CHILD} ) || exit 1
	    FILE_LIST=$( ls ${INPUT_DIR_CTL_CHILD} )
	    FLAG=0
	    for FILE in ${FILE_LIST[@]} ; do
		rm -f ${OUTPUT_DIR}/${FILE}
		ln -s ${LINK_DIR}/${FILE} ${OUTPUT_DIR}/${FILE}
		[ "${FILE}" = "${VAR}.ctl" ] && FLAG=1
	    done
	    if [ ${FLAG} -eq 0 ] ; then
		rm -f ${OUTPUT_DIR}/${VAR}.ctl
		ln -s ${LINK_DIR}/${INPUT_CTL##*/} ${OUTPUT_DIR}/${VAR}.ctl
	    fi
	fi
    done
done

if [ ${#CHSUB_BREAK_LIST[*]} -gt 0 ] ; then
    IFS=$'\n'
    CHSUB_BREAK_MIN=$( echo "${CHSUB_BREAK_LIST[*]}" | sort | head -n 1 )
    echo ""
    echo "  info: Minimum break date is ${CHSUB_BREAK_MIN}."
    echo ""
fi

echo "$0 normally finished."
