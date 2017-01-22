#
# edit below for your environment.
#

#
# necessary external library
#
export PATH=/home/hoge/bash_common/release-20150816:${PATH}
export PATH=/home/hoge/grads_ctl/release-20150818:${PATH}

. bash_common.sh

#DIR_NICAM=/home/hoge/NICAM_20150109/NICAM/bin
DIR_NICAM=/home/hoge/NICAM_20170120/NICAM/bin
BIN_NC2CTL=${DIR_NICAM}/nc2ctl
BIN_ROUGHEN=${DIR_NICAM}/roughen
BIN_Z2PRE=${DIR_NICAM}/z2pre

#
# Native (i.e. finest mesh) grid data information
#
XDEF_NAT=2560
YDEF_NAT=1280
#ZDEF_NAT=38
ZDEF_ISCCP=49
ZDEF_TYPE=ml_zlev

#
# for debug
#
VERBOSE=0
#VERBOSE=1
