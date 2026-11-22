#============================================================================
# Chameleon96: HPS interface constraints and the shared sys file list.
#
# sys_top instantiates raw Cyclone V HPS atoms. These HPS_LOCATION values
# are the ones teiram's Chameleon96 ports use for the uart and i2c
# peripheral interfaces. The spi atom is not built (MISTER_DISABLE_ALSA).
#============================================================================

set_instance_assignment -name HPS_LOCATION HPSINTERFACEPERIPHERALUART_X52_Y67_N111 -entity sys_top -to uart
set_instance_assignment -name HPS_LOCATION HPSINTERFACEPERIPHERALI2C_X52_Y60_N111 -entity sys_top -to hdmi_i2c

set_global_assignment -name PRE_FLOW_SCRIPT_FILE "quartus_sh:sys/build_id.tcl"
set_global_assignment -name QIP_FILE sys/sys.qip
