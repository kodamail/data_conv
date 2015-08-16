#!/bin/sh
START_YEAR=$1
START_MONTH=$2
END_YEAR=$3
END_MONTH=$4
INPUT_DIR=$5
OUTPUT_DIR=$6
OVERWRITE=$7   # optional
TARGET_VAR=$8   # optional

#START_YEAR=2004
#START_MONTH=6
#END_YEAR=2006
#END_MONTH=5
#INPUT_DIR=../sl/144x73/monthly_mean
#OUTPUT_DIR=../sl/144x73/clim/200406_200605/monthly_mean
#OVERWRITE="yes"
#TARGET_VAR="sa_t2m"

echo "########## monthly_clim.sh start ##########"
echo "1: $1"
echo "2: $2"
echo "3: $3"
echo "4: $4"
echo "5: $5"
echo "6: $6"
echo "7: $7"
echo "8: $8"
echo "##########"

. common.sh 
create_temp
trap "finish monthly_clim.sh" 0

if [ "${OVERWRITE}" != "yes" -a "${OVERWRITE}" != "no" -a "${OVERWRITE}" != "" ] ; then
    echo "error: OVERWRITE = ${OVERWRITE} is not supported yet"
    exit 1
fi

if [ "${TARGET_VAR}" = "" ] ; then
    VAR_LIST=(`ls ${INPUT_DIR}/`)
else
    VAR_LIST=( ${TARGET_VAR} )
fi



#VARS_LL=( la_wg la_wc la_tc la_tg la_ts la_tsn la_soil la_asn la_snw la_frs la_snrtco )
#VARS_LL=( )

#for(( i=1; $i<=10; i=$i+1 ))
#do
#    TEMP=`date +%s`
#    GS=monthly_clim_${TEMP}.gs
#    [ ! -f ${GS} ] && break
#    sleep 1s
#done
#trap "rm ${GS}" 0


#[ ${START_MONTH} -lt 10 ] && START_MONTH=0`echo "${START_MONTH} + 0" | bc`
#[ ${END_MONTH} -lt 10 ]   && END_MONTH=0`echo "${END_MONTH} + 0" | bc`

for VAR in ${VAR_LIST[@]}
do

    for(( MONTH=1; $MONTH<=12; MONTH=$MONTH+1 ))
    do

        MONTH2="${MONTH}"
        [ ${MONTH} -lt 10 ] && MONTH2="0${MONTH}"

        CLIM_START_YEAR=${START_YEAR}
        [ ${MONTH} -lt ${START_MONTH} ] \
	    && CLIM_START_YEAR=`expr ${START_YEAR} + 1`

	CLIM_END_YEAR=${END_YEAR}
	[ ${MONTH} -gt ${END_MONTH} ] && CLIM_END_YEAR=`expr ${END_YEAR} - 1`

	echo "MONTH = $MONTH2 : ${CLIM_START_YEAR} - ${CLIM_END_YEAR}"

        # input data
        INPUT_CTL=${INPUT_DIR}/${VAR}/${VAR}.ctl
        if [ ! -f ${INPUT_CTL} ] ; then
	    echo "warning: ${INPUT_CTL} does not exist"
	    echo "##########"
	    continue
	fi

        # get number of grid
	XDEF=`grads_ctl.pl ctl=${INPUT_CTL} key=XDEF target=NUM`
	YDEF=`grads_ctl.pl ctl=${INPUT_CTL} key=YDEF target=NUM`
	ZDEF=`grads_ctl.pl ctl=${INPUT_CTL} key=ZDEF target=NUM`


        # input data file size check
	for(( YEAR=${CLIM_START_YEAR}; ${YEAR}<=${CLIM_END_YEAR}; YEAR=${YEAR}+1 ))
        do
	    INPUT_DATA=${INPUT_DIR}/${VAR}/${VAR}_${YEAR}${MONTH2}.grd
	    if [ ! -f ${INPUT_DATA} ] ; then
		echo "warning: ${INPUT_DATA} does not exist"
		echo "##########"
		continue
	    fi
	    SIZE_IN=`ls -lL ${INPUT_DATA} | awk '{ print $5 }'`
	    SIZE_IN_EXACT=`echo 4*${XDEF}*${YDEF}*${ZDEF} | bc`
	    if [ ${SIZE_IN} -ne ${SIZE_IN_EXACT} ] ; then
		echo "error: File size of ${INPUT_DATA} = ${SIZE_IN} is less than expected file size = ${SIZE_IN_EXACT}"
		exit 1
	    fi

        done

        # output data
	OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_${MONTH2}.grd
	OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
	[ ! -d ${OUTPUT_DIR}/${VAR} ] && mkdir -p ${OUTPUT_DIR}/${VAR}

        # output file exist?
	if [ -f ${OUTPUT_DATA} ] ; then
	    SIZE_OUT=`ls -lL ${OUTPUT_DATA} | awk '{ print $5 }'`
	    SIZE_OUT_EXACT=`echo 4*${XDEF}*${YDEF}*${ZDEF} | bc`
	    if [ ${SIZE_OUT} -eq ${SIZE_OUT_EXACT} -a "${OVERWRITE}" != "yes" ]
		then
		echo "info: nothing to do"
		echo "##########"
		continue
	    fi
	    echo "Removing ${OUTPUT_DATA}"
	    echo ""
	    rm -f ${OUTPUT_DATA}
	fi

        # generate control file (unified)
	CTL_TDEF_STR=`grep TDEF ${INPUT_CTL} | awk '{ print $3,$4,$5 }'`

	sed ${INPUT_CTL} \
            -e "s/^DSET .*$/DSET \^${VAR}_%m2.grd/" \
	    -e "s/^TDEF .*$/TDEF  12  LINEAR 01jan0000 1mo/"  \
	> ${OUTPUT_CTL}

	GS=${TEMP_DIR}/temp.gs
	cat > ${GS} <<EOF
'reinit'
'open ${INPUT_CTL}'
rc = gsfallow("on")
'set gxout fwrite'
'set fwrite -be ${TEMP_DIR}/temp.grd'
'set undef dfile'
'set x 1 ${XDEF}'
'set y 1 ${YDEF}'
z = 1
while( z <= ${ZDEF} )
  say '  z = ' % z
  'set z 'z
  cm = cmonth($MONTH,3)
  'clave ${VAR} 'cm'%y 'cm'%y ${CLIM_START_YEAR} ${CLIM_END_YEAR}'
  z = z + 1
endwhile

'disable fwrite'
'quit'
EOF
	${GRADS_CMD} -blc ${GS}
#	grads -blc ${GS}
#	grads -lc ${GS}
	mv ${TEMP_DIR}/temp.grd ${OUTPUT_DATA}
    done
done

exit
