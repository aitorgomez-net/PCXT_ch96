#============================================================================
# Chameleon96 (5CSEBA6U19I7): device and FPGA pin assignments.
#
# Pin numbers follow the Chameleon96 ports of teiram's MiSTer cores
# (sys/pins_ch96.tcl in PET2001_MiSTer_ch96). Port names are the ones
# sys_top exposes when MISTER_CHAMELEON96 is defined.
#
# The TDA19988 video/audio/I2C pins are 1.8 V. The RF LEDs (Y19/Y20) sit on
# the 2.5 V bank and use the bank default I/O standard.
#============================================================================

set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CSEBA6U19I7
set_global_assignment -name DEVICE_FILTER_PACKAGE UFBGA
set_global_assignment -name DEVICE_FILTER_PIN_COUNT 484
set_global_assignment -name DEVICE_FILTER_SPEED_GRADE 7

# RGB565 to the TDA19988
set_location_assignment PIN_AA6  -to LCD_R[4]
set_location_assignment PIN_AA7  -to LCD_R[3]
set_location_assignment PIN_AB7  -to LCD_R[2]
set_location_assignment PIN_Y5   -to LCD_R[1]
set_location_assignment PIN_W6   -to LCD_R[0]
set_location_assignment PIN_Y11  -to LCD_G[5]
set_location_assignment PIN_AB9  -to LCD_G[4]
set_location_assignment PIN_AB8  -to LCD_G[3]
set_location_assignment PIN_AA8  -to LCD_G[2]
set_location_assignment PIN_AA5  -to LCD_G[1]
set_location_assignment PIN_AB5  -to LCD_G[0]
set_location_assignment PIN_U6   -to LCD_B[4]
set_location_assignment PIN_V5   -to LCD_B[3]
set_location_assignment PIN_V6   -to LCD_B[2]
set_location_assignment PIN_W7   -to LCD_B[1]
set_location_assignment PIN_W8   -to LCD_B[0]

set_location_assignment PIN_Y8   -to HDMI_TX_DE
set_location_assignment PIN_V10  -to HDMI_TX_HS
set_location_assignment PIN_V7   -to HDMI_TX_VS
set_location_assignment PIN_AB10 -to HDMI_TX_CLK

# I2S audio to the TDA19988
set_location_assignment PIN_V11  -to HDMI_MCLK
set_location_assignment PIN_W11  -to HDMI_SCLK
set_location_assignment PIN_AA11 -to HDMI_I2S
set_location_assignment PIN_V9   -to HDMI_LRCLK

# HPS I2C2, routed through the FPGA to the TDA19988
set_location_assignment PIN_U7   -to HDMI_I2C_SCL
set_location_assignment PIN_U10  -to HDMI_I2C_SDA

# RF LEDs
set_location_assignment PIN_Y19  -to LED_YELLOW
set_location_assignment PIN_Y20  -to LED_BLUE

set_instance_assignment -name IO_STANDARD "1.8 V" -to LCD_R[*]
set_instance_assignment -name IO_STANDARD "1.8 V" -to LCD_G[*]
set_instance_assignment -name IO_STANDARD "1.8 V" -to LCD_B[*]
set_instance_assignment -name IO_STANDARD "1.8 V" -to HDMI_TX_DE
set_instance_assignment -name IO_STANDARD "1.8 V" -to HDMI_TX_HS
set_instance_assignment -name IO_STANDARD "1.8 V" -to HDMI_TX_VS
set_instance_assignment -name IO_STANDARD "1.8 V" -to HDMI_TX_CLK
set_instance_assignment -name IO_STANDARD "1.8 V" -to HDMI_MCLK
set_instance_assignment -name IO_STANDARD "1.8 V" -to HDMI_SCLK
set_instance_assignment -name IO_STANDARD "1.8 V" -to HDMI_I2S
set_instance_assignment -name IO_STANDARD "1.8 V" -to HDMI_LRCLK
set_instance_assignment -name IO_STANDARD "1.8 V" -to HDMI_I2C_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to HDMI_I2C_SDA

set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to HDMI_I2C_SCL
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to HDMI_I2C_SDA

set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to HDMI_TX_CLK
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to LCD_R[*]
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to LCD_G[*]
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to LCD_B[*]
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to HDMI_TX_DE
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to HDMI_TX_HS
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to HDMI_TX_VS
