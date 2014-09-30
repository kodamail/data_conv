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

INPUT_DIR_CTL_LIST[$i]=../../../data_1st/output/ctl_nc/02560x01280.zorg.torg
INPUT_ML_LIST[$i]=ml_zlev
let i++


#INPUT_DIR_CTL_LIST[$i]=../../data_2nd/output/ctl_nc/00144x00072.zorg.torg
#INPUT_ML_LIST[$i]=ml_zlev
#let i++

#INPUT_DIR_CTL_LIST[$i]=../../data_2nd/output/ctl_nc/00288x00145.zorg.torg
#INPUT_ML_LIST[$i]=ml_zlev
#let i++

#INPUT_DIR_CTL_LIST[$i]=../../data_2nd/output/ctl_nc/00360x00181.zorg.torg
#INPUT_ML_LIST[$i]=ml_zlev
#let i++

#INPUT_DIR_CTL_LIST[$i]=../../data_2nd/output/ctl_nc/00144x00072.p37.torg
#INPUT_ML_LIST[$i]=ml_plev
#let i++

#INPUT_DIR_CTL_LIST[$i]=../../data_2nd/output/ctl_nc/00288x00145.p37.torg
#INPUT_ML_LIST[$i]=ml_plev
#let i++

#INPUT_DIR_CTL_LIST[$i]=../../data_2nd/output/ctl_nc/00360x00181.p26.torg
#INPUT_ML_LIST[$i]=ml_plev
#let i++

#----------------------------------------#
