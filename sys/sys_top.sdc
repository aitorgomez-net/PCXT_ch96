# Specify root clocks
set mister_ch96 0
foreach_in_collection a [get_all_global_assignments -name VERILOG_MACRO] {
   if {[lindex $a 2] eq "MISTER_CHAMELEON96"} { set mister_ch96 1 }
}
if {$mister_ch96} {
   # The Chameleon96 has no FPGA-side oscillator. FPGA_CLK1/2/3_50 are one
   # net fed by HPS h2f_user1_clk; it keeps the FPGA_CLK2_50 clock name so
   # the constraints that refer to the 50 MHz system clock still apply.
   create_clock -period "50.0 MHz" [get_pins -compatibility_mode *|h2f_user1_clk] -name FPGA_CLK2_50
} else {
create_clock -period "50.0 MHz"  [get_ports FPGA_CLK1_50]
create_clock -period "50.0 MHz"  [get_ports FPGA_CLK2_50]
create_clock -period "50.0 MHz"  [get_ports FPGA_CLK3_50]
}
create_clock -period "100.0 MHz" [get_pins -compatibility_mode *|h2f_user0_clk]
# The HPS SPI master only exists when ALSA is built in.
set spi_sck_pin [get_pins -nowarn -compatibility_mode spi|sclk_out]
if {[get_collection_size $spi_sck_pin]} {
create_clock -period "100.0 MHz" $spi_sck_pin -name spi_sck
}
create_clock -period "10.0 MHz"  [get_pins -compatibility_mode hdmi_i2c|out_clk] -name hdmi_sck

derive_pll_clocks
derive_clock_uncertainty

# Decouple different clock groups (to simplify routing)
set_clock_groups -exclusive \
   -group [get_clocks { *|pll|pll_inst|altera_pll_i|*[*].*|divclk}] \
   -group [get_clocks { pll_hdmi|pll_hdmi_inst|altera_pll_i|*[0].*|divclk}] \
   -group [get_clocks { pll_audio|pll_audio_inst|altera_pll_i|*[0].*|divclk}] \
   -group [get_clocks { spi_sck}] \
   -group [get_clocks { hdmi_sck}] \
   -group [get_clocks { *|h2f_user0_clk}] \
   -group [get_clocks { FPGA_CLK1_50 }] \
   -group [get_clocks { FPGA_CLK2_50 }] \
   -group [get_clocks { FPGA_CLK3_50 }]

# The Cyclone V f2sdram timing model can attribute an output of one DDR port
# to the clock of another, which shows up as paths between the ports' clocks
# through the HPS hard block (ram1 = the core's DDRAM_CLK, ram2 = audio,
# vbuf = scaler on h2f_user0_clk). They are not real, and repairing their
# "hold" makes the fitter add tens of ns of routing. Same exceptions as the
# PCAT-286 Chameleon96 port; direct FPGA logic crossings stay timed.
# ram1 is clk_sdram (pll_system general[2]) on the Chameleon96 build; on the
# DE10-Nano build DDRAM_CLK is another clock and the general[2] entry matches nothing
# that goes through the hard block. Clocks that are not found are skipped.
set hps_ddr_pins [get_pins -compatibility_mode -nowarn {*|f2sdram|*}]
set ddr_port_clocks {}
foreach pat {{*pll_system_inst*general[2]*divclk} {pll_audio*general[0]*divclk} {*h2f_user0_clk}} {
   set c [get_clocks -nowarn $pat]
   if {[get_collection_size $c] == 1} { lappend ddr_port_clocks $c }
}
if {[get_collection_size $hps_ddr_pins] > 0} {
   set n [llength $ddr_port_clocks]
   for {set i 0} {$i < $n} {incr i} {
      for {set j 0} {$j < $n} {incr j} {
         if {$i != $j} {
            set_false_path -from [lindex $ddr_port_clocks $i] -through $hps_ddr_pins -to [lindex $ddr_port_clocks $j]
         }
      }
   }
}

# sysmem synchronizes its reset separately in each DDR port clock domain; only
# the first stage of each may see the asynchronous transition.
foreach reset_port {ram1 ram2 vbuf} {
   set reset_meta [get_registers -nowarn "*|${reset_port}_reset_0"]
   if {[get_collection_size $reset_meta] == 1} { set_false_path -to $reset_meta }
}

if {$mister_ch96} {
set_false_path -to   [get_ports {LED_*}]
} else {
set_false_path -from [get_ports {KEY*}]
set_false_path -from [get_ports {BTN_*}]
set_false_path -to   [get_ports {LED_*}]
set_false_path -to   [get_ports {VGA_*}]
set_false_path -from [get_ports {VGA_EN}]
set_false_path -to   [get_ports {AUDIO_SPDIF}]
set_false_path -to   [get_ports {AUDIO_L}]
set_false_path -to   [get_ports {AUDIO_R}]
set_false_path -from {get_ports {SW[*]}}
}
set_false_path -to   {cfg[*]}
set_false_path -from {cfg[*]}
set_false_path -from {VSET[*]}
set_false_path -to   {wcalc[*] hcalc[*]}
set_false_path -to   {hdmi_width[*] hdmi_height[*]}
set_false_path -to   {deb_* btn_en btn_up}

set_multicycle_path -to {*_osd|osd_vcnt*} -setup 2
set_multicycle_path -to {*_osd|osd_vcnt*} -hold 1

set_false_path -to   {*_osd|v_cnt*}
set_false_path -to   {*_osd|v_osd_start*}
set_false_path -to   {*_osd|v_info_start*}
set_false_path -to   {*_osd|h_osd_start*}
set_false_path -from {*_osd|v_osd_start*}
set_false_path -from {*_osd|v_info_start*}
set_false_path -from {*_osd|h_osd_start*}
set_false_path -from {*_osd|rot*}
set_false_path -from {*_osd|dsp_width*}
set_false_path -to   {*_osd|half}

set_false_path -to   {WIDTH[*] HFP[*] HS[*] HBP[*] HEIGHT[*] VFP[*] VS[*] VBP[*]}
set_false_path -from {WIDTH[*] HFP[*] HS[*] HBP[*] HEIGHT[*] VFP[*] VS[*] VBP[*]}
set_false_path -to   {FB_BASE[*] FB_BASE[*] FB_WIDTH[*] FB_HEIGHT[*] LFB_HMIN[*] LFB_HMAX[*] LFB_VMIN[*] LFB_VMAX[*]}
set_false_path -from {FB_BASE[*] FB_BASE[*] FB_WIDTH[*] FB_HEIGHT[*] LFB_HMIN[*] LFB_HMAX[*] LFB_VMIN[*] LFB_VMAX[*]}
set_false_path -to   {vol_att[*] scaler_flt[*] led_overtake[*] led_state[*]}
set_false_path -from {vol_att[*] scaler_flt[*] led_overtake[*] led_state[*]}
set_false_path -from {aflt_* acx* acy* areset* arc*}
set_false_path -from {arx* ary*}
set_false_path -from {vs_line*}
set_false_path -from {ColorBurst_Range* PhaseInc* pal_en cvbs yc_en}

set_false_path -from {ascal|o_ihsize*}
set_false_path -from {ascal|o_ivsize*}
set_false_path -from {ascal|o_format*}
set_false_path -from {ascal|o_hdown}
set_false_path -from {ascal|o_vdown}
set_false_path -from {ascal|o_hmin* ascal|o_hmax* ascal|o_vmin* ascal|o_vmax* ascal|o_vrrmax* ascal|o_vrr}
set_false_path -from {ascal|o_hdisp* ascal|o_vdisp*}
set_false_path -from {ascal|o_htotal* ascal|o_vtotal*}
set_false_path -from {ascal|o_hsstart* ascal|o_vsstart* ascal|o_hsend* ascal|o_vsend*}
set_false_path -from {ascal|o_hsize* ascal|o_vsize*}

if {!$mister_ch96} {
set_false_path -from {mcp23009|flg_*}
}
set_false_path -to   {sysmem|fpga_interfaces|clocks_resets|f2h*}
