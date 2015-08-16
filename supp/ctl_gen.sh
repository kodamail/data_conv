#!/bin/sh
#
# combine NICAM control files into single one.
#
# [History]
#   2012.07.XX  C.Kodama : support for NetCDF.
#
# Before execution, check
# -VAR="?l_*" and "dfq_isccp2" is snapshot or mean
#

########################################
##### specify the following variables
#
#EXT=ctl
EXT=nc
# list of days -> TID (time ID)
TID_LIST=( $( ls ../ | grep dy ) )
#TID_LIST=( $( ls -d ../output_000* | grep dy | cut -d / -f 2 ) )
#TID_LIST=( \
#    output_00001-00005dy \
#    output_00006-00010dy )
#
# relative path for the NICAM directory (output_?????dy)
DIR_NICAM_OUTPUT=..
#
# path for the grid data directory relative to 
# the DIR_NICAM_OUTPUT/${TID}
DIR_NICAM_GRD=
#DIR_NICAM_GRD=data_nc
#DIR_NICAM_GRD=data_grd/interp/144x72.p17.torg
#DIR_NICAM_GRD=data_grd/interp/$( pwd | sed -e "s|/|\n|g" | tail -n 1 )
#
# (if necessary) force to set TDEF_START
#TDEF_START_FORCE=""
TDEF_START_FORCE="00:00Z01JUN2004"
#
# (if necessary) shift TDEF_START to reflect snapshot/average mode
TDEF_START_SHIFT="yes"
#
# assume chsub time increment is constant in all the time range
#FLAG_CHSUB_INCRE_CNST=0
FLAG_CHSUB_INCRE_CNST=1
#
########################################

export LANG=en

DIR_FIRST=${DIR_NICAM_OUTPUT}/${TID_LIST[0]}/${DIR_NICAM_GRD}
DIR_SECOND=${DIR_NICAM_OUTPUT}/${TID_LIST[1]}/${DIR_NICAM_GRD}
cd ${DIR_FIRST}

VAR_LIST=( $( ls *.${EXT} | sed -e "s/.${EXT}//" ) )
#CTL_LIST=( $( ls *.ctl ) )
cd -


#for CTL in ${CTL_LIST[@]} ; do
for VAR in ${VAR_LIST[@]} ; do
    #echo ${CTL}
    #VAR=$( echo ${CTL} | sed -e "s/\.ctl//" )
    echo ${VAR}
    CTL=${VAR}.ctl
    rm -f ${CTL}.chsub
    CHSUB_START=1
    CHSUB_END=0
    for TID in ${TID_LIST[@]} ; do

	if [ "${EXT}" = "ctl" ] ; then
            [ ! -f "${DIR_NICAM_OUTPUT}/${TID}/${DIR_NICAM_GRD}/${CTL}" ] && break
            CHSUB_INCRE=$( grep "^TDEF" ${DIR_NICAM_OUTPUT}/${TID}/${DIR_NICAM_GRD}/${CTL} | awk '{ print $2 }' )

	elif [ "${EXT}" = "nc" ] ; then
            [ ! -f "${DIR_NICAM_OUTPUT}/${TID}/${DIR_NICAM_GRD}/${VAR}.nc" ] && break
	    if [ ${FLAG_CHSUB_INCRE_CNST} -ne 1 -o "${TID}" = "${TID_LIST[0]}" ] ; then
		CHSUB_INCRE=$( ncdump  -h ${DIR_NICAM_OUTPUT}/${TID}/${DIR_NICAM_GRD}/${VAR}.nc \
		    | sed -e "/^dimensions:/,/^variables:/p" -e d \
		    | grep "time = " \
		    | awk '{ print $3 }' )
	    fi
	else
	    echo "EXT=${EXT} is not supported"
	    exit 1
	fi

#	CHSUB_END=$( echo "${CHSUB_START} + ${CHSUB_INCRE} - 1" | bc )
	let CHSUB_END=CHSUB_START+CHSUB_INCRE-1
	echo "CHSUB  ${CHSUB_START}  ${CHSUB_END}  ${TID}" >> ${CTL}.chsub
#	CHSUB_START=$( echo "${CHSUB_END} + 1" | bc )
	let CHSUB_START=CHSUB_END+1

    done
    TDEF=${CHSUB_END}

    if [ "${EXT}" = "ctl" ] ; then
	TDEF_START=$( grep "^TDEF" ${DIR_FIRST}/${CTL} | awk '{ print $4 }' )
	TDEF_INT=$(   grep "^TDEF" ${DIR_FIRST}/${CTL} | awk '{ print $5 }' )

    elif [ "${EXT}" = "nc" ] ; then
	TDEF_TMP=$( ncdump -c ${DIR_FIRST}/${VAR}.nc \
	    | sed -e '/data:/,/time =/p' -e d \
	    | tail -n 1  \
	    | sed -e "s/time =//" \
	    | sed -e "s/; *$//" )
	
	TDEF_UNITS=( $( ncdump -h ${DIR_FIRST}/${VAR}.nc \
	    | grep "time:units" \
	    | cut -d = -f 2 \
	    | cut -d \" -f 2 ) )

	TDEF_1=$( echo ${TDEF_TMP} | cut -s -d , -f 1 )
	TDEF_2=$( echo ${TDEF_TMP} | cut -s -d , -f 2 )

	if [ "${TDEF_1}" = "" ] ; then  # in case of only 1 step
	    TDEF_1=$( echo ${TDEF_TMP} | cut -s -d \; -f 1 )
	    TDEF_FIRST=( $( ncdump -h ${DIR_FIRST}/${VAR}.nc \
		| grep "time:units" \
		| cut -d = -f 2 \
		| cut -d \" -f 2 ) )
	    TDEF_SECOND=( $( ncdump -h ${DIR_SECOND}/${VAR}.nc \
		| grep "time:units" \
		| cut -d = -f 2 \
		| cut -d \" -f 2 ) )

	    SEC1=$( date -u --date "${TDEF_FIRST[2]}  ${TDEF_FIRST[3]}"  +%s )
	    SEC2=$( date -u --date "${TDEF_SECOND[2]} ${TDEF_SECOND[3]}" +%s )
	    TDEF_INT=$( echo "( ${SEC2} - ${SEC1} ) / 60" | bc )
	    TDEF_INT="${TDEF_INT}mn"
	    TDEF_UNITS[0]="minutes"

	else
#	    TDEF_INT=$( echo "${TDEF_2} - ${TDEF_1}" | bc )
	    let TDEF_INT=TDEF_2-TDEF_1
	    TDEF_INT=${TDEF_INT}$( echo ${TDEF_UNITS[0]} \
		| sed -e "s/minutes/mn/" -e "s/hours/hr/" -e "s/days/dy/" )
	fi

	TDEF_START=$( date -u --date "${TDEF_UNITS[2]} ${TDEF_UNITS[3]} ${TDEF_1} ${TDEF_UNITS[0]}" +%H:%Mz%d%b%Y )

    fi
    [ "${TDEF_START_FORCE}" != "" ] && TDEF_START=${TDEF_START_FORCE}
    TDEF_INT_TMP=$( echo ${TDEF_INT} | sed -e "s/mn//" -e "s/hr/*60/" -e "s/*24*60/ days/" | bc )


    # shift time
    #   snapshot: +TDEF_INT
    #   average : +TDEF_INT/2
    if [ "${TDEF_START_SHIFT}" = "yes" ] ; then
#	SA=$( echo ${VAR} | cut -b 2 )
	SA=${VAR:1:1}
	if [ "${SA}" = "s" -o "${SA}" = "l" ] ; then  # snapshot
	    TDEF_START=$( date -u --date "${TDEF_START} ${TDEF_INT_TMP} mins" +%H:%Mz%d%b%Y )
	elif [ "${SA}" = "a" -o "${VAR}" = "dfq_isccp2" ] ; then  # mean
	    TDEF_INT_TMP2=$( echo "${TDEF_INT_TMP} / 2" | bc )
	    TDEF_START=$( date -u --date "${TDEF_START} ${TDEF_INT_TMP2} mins" +%H:%Mz%d%b%Y )
	else
	    echo "SA=${SA} (VAR=${VAR}) is not supported"
	    exit
	fi
    fi
    #echo ${TDEF_START}
    
    if [ "${EXT}" = "ctl" ] ; then
	sed ${DIR_FIRST}/${CTL} \
	    -e "s|^DSET .*$|DSET ^${DIR_NICAM_OUTPUT}/%ch/${DIR_NICAM_GRD}/${VAR}.grd|" \
	    -e "s|^OPTIONS|OPTIONS TEMPLATE|" \
	    -e "s|^TDEF .*$|TDEF    ${TDEF} LINEAR ${TDEF_START} ${TDEF_INT}|" \
	    -e "s|^tmp |${VAR} |" \
	    > ${CTL}.tmp
	sed -e "/^DSET/q" ${CTL}.tmp > ${CTL}
	cat ${CTL}.chsub >> ${CTL}
	sed -e "0,/^DSET/d" ${CTL}.tmp >> ${CTL}
	rm -f ${CTL}.tmp 

    elif [ "${EXT}" = "nc" ] ; then
	echo "DSET ^${DIR_NICAM_OUTPUT}/%ch/${DIR_NICAM_GRD}/${VAR}.nc" > ${CTL}
	echo "OPTIONS TEMPLATE" >> ${CTL}
	cat ${CTL}.chsub >> ${CTL}
	echo "TDEF   time   ${TDEF} LINEAR ${TDEF_START} ${TDEF_INT}" >> ${CTL}
	echo "* use \"xdfopen\" instead of \"open\"." >> ${CTL}

    fi

    rm -f ${CTL}.chsub

done
