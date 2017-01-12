#
# configurations specific for RUNID
#   (RUNID=def: default)
#

INPUT_TOP_RDIR=../../../data_1st

OUTPUT_TOP_RDIR=../../../data_conv
#OUTPUT_TOP_RDIR=../..
#OUTPUT_TOP_RDIR=test


#----------------------------------------#
#
# for link.sh
#

# do not delete existing symbolic links
USE_OLD=1

i=0
INPUT_RDIR_CTL_LIST=() ; INPUT_ML_LIST=()

INPUT_RDIR_CTL_LIST[$i]=${INPUT_TOP_RDIR}/data_1st/output/ctl_nc/02560x01280.zorg.torg
INPUT_ML_LIST[$i]=ml_zlev
INPUT_TIME_LIST[$i]=tstep
EXT_LIST[$i]=nc
let i++

#INPUT_RDIR_CTL_LIST[$i]=${INPUT_TOP_RDIR}/data_1st/output/ctl_nc/00144x00072.zorg.torg
#INPUT_RDIR_CTL_LIST[$i]=${INPUT_TOP_RDIR}/data_2nd/output/ctl_nc/00144x00072.zorg.torg
#INPUT_ML_LIST[$i]=ml_zlev
#INPUT_TIME_LIST[$i]=tstep
#EXT_LIST[$i]=nc
#let i++

#INPUT_RDIR_CTL_LIST[$i]=${INPUT_TOP_RDIR}/data_1st/output/ctl_nc/00288x00145.zorg.torg
#INPUT_RDIR_CTL_LIST[$i]=${INPUT_TOP_RDIR}/data_2nd/output/ctl_nc/00288x00145.zorg.torg
#INPUT_ML_LIST[$i]=ml_zlev
#INPUT_TIME_LIST[$i]=tstep
#EXT_LIST[$i]=nc
#let i++

#INPUT_RDIR_CTL_LIST[$i]=${INPUT_TOP_RDIR}/data_1st/output/ctl_nc/00360x00181.zorg.torg
#INPUT_RDIR_CTL_LIST[$i]=${INPUT_TOP_RDIR}/data_2nd/output/ctl_nc/00360x00181.zorg.torg
#INPUT_ML_LIST[$i]=ml_zlev
#INPUT_TIME_LIST[$i]=tstep
#EXT_LIST[$i]=nc
#let i++

#INPUT_RDIR_CTL_LIST[$i]=${INPUT_TOP_RDIR}/data_1st/output/ctl_nc/00144x00072.p37.torg
#INPUT_RDIR_CTL_LIST[$i]=${INPUT_TOP_RDIR}/data_2nd/output/ctl_nc/00144x00072.p37.torg
#INPUT_ML_LIST[$i]=ml_plev
#INPUT_TIME_LIST[$i]=tstep
#EXT_LIST[$i]=nc
#let i++

#INPUT_RDIR_CTL_LIST[$i]=${INPUT_TOP_RDIR}/data_1st/output/ctl_nc/00288x00145.p37.torg
#INPUT_RDIR_CTL_LIST[$i]=${INPUT_TOP_RDIR}/data_2nd/output/ctl_nc/00288x00145.p37.torg
#INPUT_ML_LIST[$i]=ml_plev
#INPUT_TIME_LIST[$i]=tstep
#EXT_LIST[$i]=nc
#let i++

#INPUT_RDIR_CTL_LIST[$i]=${INPUT_TOP_RDIR}/data_1st/output/ctl_nc/00360x00181.p26.torg
#INPUT_RDIR_CTL_LIST[$i]=${INPUT_TOP_RDIR}/data_2nd/output/ctl_nc/00360x00181.p26.torg
#INPUT_ML_LIST[$i]=ml_plev
#INPUT_TIME_LIST[$i]=tstep
#EXT_LIST[$i]=nc
#let i++

#----------------------------------------#
