# Main_MiSTer patch for the TDA19988

`0003-tda19988-synchs-pol-avi.patch` applies to `video.cpp` of teiram's
Main_MiSTer_ch96 at commit `d9799de` (`patch -p0 < 0003-tda19988-synchs-pol-avi.patch`
from the Main_MiSTer root). It changes how `tda_config_set_mode` programs the
TDA19988: SYNC_HS mode instead of the SYNC_DE passthrough (the timing generator locks
to the HS/VS edges and regenerates DE, as the Linux tda998x and u-boot drivers do), the
mode's sync polarity applied at the TBG output instead of inverting the input,
`VIDFORMAT` always 0x00 with the full timing programmed, and an AVI InfoFrame with
picture aspect "no data" for modes without a CEA VIC (custom modelines, 1024x768,
1280x1024), which otherwise get no picture on a monitor. Build it as the stock Main,
with an Ubuntu focal gcc-9 armhf cross compiler (`arm-linux-gnueabihf-gcc-9`) and
`-mcpu=cortex-a9 -mfpu=neon -mfloat-abi=hard`; the resulting `MiSTer` binary replaces
`F:\MiSTer` on the SD card (back up the old one first).
