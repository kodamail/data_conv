#
# edit below for your environment.
#

#
# necessary external library
#
export PATH=/bwork3/kodama/program/sh/bash_common/release-20151012:${PATH}
export PATH=/bwork3/kodama/program/sh/grads_ctl/release-20151006:${PATH}

. bash_common.sh

#DIR_NICAM=/bwork3/kodama/NICAM_src/NICAM_20140929/bin
DIR_NICAM=/bwork3/kodama/NICAM_src/NICAM_20161217/NICAM/bin
BIN_NC2CTL=${DIR_NICAM}/nc2ctl
BIN_ROUGHEN=${DIR_NICAM}/roughen
BIN_Z2PRE=${DIR_NICAM}/z2pre


#
# Native (i.e. finest mesh) grid data information
#
#XDEF_NAT=640
#YDEF_NAT=320
##ZDEF_NAT=38
#ZDEF_ISCCP=49
#ZDEF_TYPE=ml_zlev

#
# for debug
#
#VERBOSE=0
#VERBOSE=1
