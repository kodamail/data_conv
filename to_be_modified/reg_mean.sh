#!/bin/sh
#
# dependency of other script
#   *_*_tstep_var.sh
#
# output
#   */*/monthly_mean/
#


DAYS=$1
INPUT_DIR=$2
OUTPUT_DIR=$3
LONMIN=$4
LONMAX=$5
LATMIN=$6
LATMAX=$7
SW=$8           # optional: all(default), only-land, only-ocean
REF_CTL=$9      # optional: veget_mat
TARGET_VAR=${10} # optional

echo "reg_mean.sh start"
echo "$1"
echo "$2"
echo "$3"
echo "$4"
echo "$5"
echo "$6"
echo "$7"
echo "$8"
echo "$9"
echo "${10}"
echo ""

for(( i=1; $i<=10; i=$i+1 ))
do
    TEMP=`date +%s`
    GS=reg_mean_${TEMP}.gs
    [ ! -f ${GS} ] && break
    sleep 1s
done
trap "rm ${GS}" 0
touch ${GS}


VAR_LIST=(`ls ${INPUT_DIR}`)

for VAR in ${VAR_LIST[@]}
do
    [ "${TARGET_VAR}" != "" -a "${TARGET_VAR}" != "${VAR}" ] && continue
    echo "  ${VAR}"

    [ ! -d ${OUTPUT_DIR}/${VAR} ] && mkdir -p ${OUTPUT_DIR}/${VAR}
    INPUT_CTL=${INPUT_DIR}/${VAR}/${VAR}.ctl
    OUTPUT_CTL=${OUTPUT_DIR}/${VAR}/${VAR}.ctl
    OUTPUT_DATA=${OUTPUT_DIR}/${VAR}/${VAR}_output_${DAYS}dy.grd

    source grads_ctl.sh ${INPUT_CTL}
    XDEF=`get_XDEF`
    YDEF=`get_YDEF`
    ZDEF=`get_ZDEF`

    CHSUB=`grep -i ^CHSUB ${INPUT_CTL} | grep ${DAYS}$`
    INPUT_TMIN=`echo ${CHSUB} | awk '{ print $2 }'`
    INPUT_TMAX=`echo ${CHSUB} | awk '{ print $3 }'`

    # create control file
    sed ${INPUT_CTL} \
            -e "s/^DSET .*$/DSET \^${VAR}_output_%chdy.grd/" \
            -e "/^XDEF/,/^YDEF/{" \
            -e "/^\(XDEF\|YDEF\)/!D" \
            -e "}" \
            -e "s/^XDEF.*/XDEF  1  LEVELS  0.0/" \
            -e "/^YDEF/,/^ZDEF/{" \
            -e "/^\(YDEF\|ZDEF\)/!D" \
            -e "}" \
            -e "s/^YDEF.*/YDEF  1  LEVELS  0.0/" \
        > ${OUTPUT_CTL}


    # little or big endian
    OPT_ENDIAN=""
    FLAG_BIG_ENDIAN=`get_OPTIONS big_endian`
    FLAG_LITTLE_ENDIAN=`get_OPTIONS little_endian`
    [ "${FLAG_BIG_ENDIAN}" = "1" -a "${FLAG_LITTLE_ENDIAN}" = "1" ] \
	&& echo "error: Ambiguous endian specifications" \
	&& exit
    [ "${FLAG_BIG_ENDIAN}" = "1" ]    && OPT_ENDIAN="-be"
    [ "${FLAG_LITTLE_ENDIAN}" = "1" ] && OPT_ENDIAN="-le"
    cat > ${GS} <<EOF
'reinit'
rc = gsfallow( 'on' )
'open ${INPUT_CTL}'
'set gxout fwrite'
'set undef dfile'
'set fwrite ${OPT_ENDIAN} ${OUTPUT_DATA}'
if( valnum('${INPUT_TMIN}') = 0 )
  t_start = time2t( '${INPUT_TMIN}' )
else
  t_start = '${INPUT_TMIN}'
endif
if( valnum('${INPUT_TMAX}') = 0 )
  t_end = time2t( '${INPUT_TMAX}' )
else
  t_end = '${INPUT_TMAX}'
endif

'mask = const( ${VAR}, 1, -a )'
if( '${SW}' = 'only-land' | '${SW}' = 'only-ocean' )
  'open ${REF_CTL}'
  'set dfile 2'
  'set lon ${LONMIN} ${LONMAX}'
  'set lat ${LATMIN} ${LATMAX}'
  'set z 1'
  'set t 1'
  'veg = veget_mat.2'
*  land: 1  ocean: -1
  'land = const( maskout( const(veg,1,-a), veg-0.5 ), -1, -u)'
  'set dfile 1'
  'set lon ${LONMIN} ${LONMAX}'
  'set lat ${LATMIN} ${LATMAX}'
  'set z 1'
  'set t 1'
  'mask = lterp( land, ${VAR} )'
  if( '${SW}' = 'only-ocean' )
    'mask = -mask'
  endif
*  'set gxout shaded'
*  'd mask'
*  'cbar'
*  exit
*if( '${SW}' = 'only-land' )
*'mask'
endif

'set x 1'
'set y 1'
say 't: ' % t_start % ' - ' t_end
t = t_start
while( t <= t_end )
   say '    t = ' % t % ' / ' t_end
   'set t 't
   z = 1
   while( z <= ${ZDEF} )
    'set z 'z
    'd aave( maskout(${VAR},mask), lon=${LONMIN}, lon=${LONMAX}, lat=${LATMIN}, lat=${LATMAX} )'
    'c'
    z = z + 1
  endwhile

  t = t + 1
endwhile

'disable fwrite'
'quit'
EOF

    grads -blc ${GS}
#    grads -lc ${GS}

done

echo "reg_mean.sh end"
