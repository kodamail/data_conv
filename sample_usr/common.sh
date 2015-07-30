#
# edit below for your environment.
#

# necessary external library
export PATH=/cwork5/kodama/program/sh_lib/bash_common/release-20150719:${PATH}
export PATH=/cwork5/kodama/program/sh_lib/grads_ctl/release-20150717:${PATH}
export PATH=/cwork5/kodama/program/sh_lib/diff-path/0.01r3:${PATH}
export PATH=/cwork5/kodama/program/for/zonal_mean/0.03r1:${PATH}
BIN_DIFF_PATH=diff-path
BIN_ZONAL_MEAN=zonal_mean

DIR_NICAM=/cwork5/kodama/NICAM_src/NICAM_20150109/NICAM/bin
BIN_NC2CTL=${DIR_NICAM}/nc2ctl
BIN_ROUGHEN=${DIR_NICAM}/roughen
BIN_Z2PRE=${DIR_NICAM}/z2pre


#
# Native (i.e. finest mesh) grid data information
#
XDEF_NAT=2560
YDEF_NAT=1280
ZDEF_NAT=38
ZDEF_ISCCP=49
