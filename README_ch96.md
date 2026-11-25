# PCXT for Chameleon96

Port of the PCXT core (IBM PC/XT, Tandy 1000, IBM PCjr) to the Arrow/Novtech
Chameleon96 board (Cyclone V SE 5CSEBA6U19I7, same die as the DE10-Nano), for
the MiSTer port to that board by Manuel Teira (teiram) and the distribution by
Shaeon (Distribution_MiSTer_ch96).

**Status: first test build.** The core RAM, ROMs and video memory live in the
HPS DDR3 (`platform/ch96/ddram_ctrl.sv`). Not yet checked on the board.

## Approach

Same as the PCAT-286 port (Maverick-Shark/pcat-286_mister, branch `ch96`):

- `sys/` is PCXT_MiSTer's own framework. Every board difference is behind the
  `MISTER_CHAMELEON96` macro, and the DE10-Nano view of each edited file is unchanged,
  so `PCXT.qpf` still builds the DE10-Nano core from this tree.
- `sys_top` stays the top-level entity (teiram's template wraps it in `ch96_top`
  instead). `SYSTEM.sdc` and `sys/sys_top.sdc` name instances relative to `sys_top`,
  so they keep applying; both detect `MISTER_CHAMELEON96` and skip the constraints
  of pins the board does not have (SDRAM, SDIO, analog I/O, MCP23009, switches).
- The HPS-fed 50 MHz clock keeps the `FPGA_CLK2_50` name.
- HDMI PLL powers up at 74.25 MHz (720p60), as in the template; Main_MiSTer
  reprograms it for the selected mode.

## Origin

| Part | Source | Commit |
|---|---|---|
| Core and `sys/` | aitorgomez-net/PCXT_MiSTer | bd8a78e |
| Chameleon96 changes in `sys/` (`sys_top.v/.sdc`, `sysmem.sv`, `pll_hdmi_0002.v`, `pins_ch96.tcl`, `hps_ch96.tcl`) | Maverick-Shark/pcat-286_mister `ch96` | f034f09 |
| Board data (pins, HPS locations, memory map) | teiram/Template_MiSTer_ch96 | aacd20d |

## Build

Quartus 17.0.2 Lite (same as MiSTer), e.g. with Docker in WSL:

    docker run --rm -v "$PWD":/build -w /build raetro/quartus:17.0 \
        quartus_sh --flow compile PCXT_ch96

`PCXT_ch96.qpf` is the Chameleon96 build, `PCXT.qpf` the DE10-Nano one.
Profile: `PCXT_PROFILE=<profiles/name>` (default `mister_pcxt_full`).
Output: `output_files/PCXT_ch96.rbf`. Release name: `releases/PCXT_AAAAMMDD_ch96.rbf`.

## What changes on this board (MISTER_CHAMELEON96)

| Area | DE10-Nano | Chameleon96 |
|---|---|---|
| 50 MHz clocks | three oscillator pins | HPS `h2f_user1_clk` |
| Video | ADV7513, RGB888 | TDA19988, RGB565 |
| SDRAM, VGA, analog audio, SDIO, ADC, user port, I/O board | pins | internal nets, tied off |
| ALSA audio from Linux | yes | no |
| 350-line CRT conversion (DDR3 capture + 15 kHz raster) | yes | off, OSD entry hidden |
| 2nd SD card | OSD option | hidden, forced off |
| Scaler buffer (`RAMBASE`) | `0x20000000` | `0x1E800000` |

With the 350-line conversion off, the `DDRAM_*` port is free for the core RAM.

### Video fetch lead

The DDR3 is shared with the scaler and Linux, and a read sometimes takes longer than the
one character of lead the video fetch had with the SDRAM: in text modes a late word shows
up as a stray glyph (dots, dashes, bullets). On this board the cards ask for their words
further ahead (`sdram_pkg`, under `MISTER_CHAMELEON96`):

| Card | How | Lead per read |
|---|---|---|
| CGA | draws 64 clocks behind its CRTC (`crtc_delay.sv`) | 5 characters in 80 columns (2.8 us), 3 in 40 |
| HGC/MDA | 5 characters behind in text, 3 in graphics | 6 characters in text (1.9 us), 4 in graphics (2.2 us) |
| EGA | `SDRAM_LEAD_DOTS` 56, cell 29 + glyph 30 dots | 1.8 us per text read, 3.4 us in graphics |

Up to 8 video reads may be in flight at once (4 with the SDRAM), and the DDR3 controller
keeps 16.

The picture only moves as a whole (syncs and blanking are delayed with it). The
DE10-Nano build keeps the old values. Benches: `video_chain_*_lead` in
`rtl/mem/TESTBENCH/run_tests.sh` (latency spikes of 1.3 us in 5 % of the reads).

## DDR3 map

Linux owns `0x00000000-0x0FFFFFFF`; the device tree reserves `0x10000000-0x1FFFFFFF`
for the FPGA. Free for cores: `0x10000000-0x1CFFFFFF` (ao486 uses it too, only one RBF is
loaded at a time). Main_MiSTer framebuffer at `0x1D000000`, scaler at `0x1E800000`.
Proposed for the PCXT RAM: `0x11000000`, as the PCAT-286 port (above Main_MiSTer's
x86 share poll at `0x100CE000`).

## To do (port)

1. ~~`platform/ch96/ddram_ctrl.sv`: DDR3 backend for `sdram_arbiter`.~~ Done. With one
   character of lead some text reads were late; see "Video fetch lead".
2. If they do not: video memory (CGA/HGC/EGA) back to BRAM, with a BRAM mirror of the Tandy/PCjr video RAM
   fed by the write snoop, so video never waits on DDR3 latency.
3. OSD: hide USER I/O and MT32-pi on this board (no user port), as PCAT-286 does.
4. Main_MiSTer_ch96: check that it carries the PCXT-specific support of upstream Main_MiSTer.
