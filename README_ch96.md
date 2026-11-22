# PCXT for Chameleon96

Port of the PCXT core (IBM PC/XT, Tandy 1000, IBM PCjr) to the Arrow/Novtech
Chameleon96 board (Cyclone V SE 5CSEBA6U19I7, same die as the DE10-Nano), on top
of the MiSTer port for that board by Manuel Teira (teiram) and the distribution
by Shaeon (Distribution_MiSTer_ch96).

**Status: scaffolding only.** The project builds for the board, but the core's
memory still targets an SDRAM that the Chameleon96 does not have.

## Origin

| Part | Source | Commit |
|---|---|---|
| Core (everything except `sys/`) | aitorgomez-net/PCXT_MiSTer | bd8a78e |
| Framework `sys/` (unmodified) | teiram/Template_MiSTer_ch96 | aacd20d |
| `PCXT_ch96.qsf` / `.qpf` / `.sdc` | Template_ch96 project + PCXT.qsf settings | |

Changes from PCXT_MiSTer: DE10-Nano project files (`PCXT.qpf/.qsf`), `.github/`
and release binaries removed; `sys/` replaced; PSRAM ports tied off in `PCXT.sv`.

## Build

Quartus 17.0.2 Lite (same as MiSTer), e.g. with Docker in WSL:

    docker run --rm -v "$PWD":/build -w /build raetro/quartus:17.0 \
        quartus_sh --flow compile PCXT_ch96

Profile: `PCXT_PROFILE=<profiles/name>` as in PCXT_MiSTer (default `mister_pcxt_full`).
Output: `output_files/PCXT_ch96.rbf`. Release name: `releases/PCXT_AAAAMMDD_ch96.rbf`.

## Board constraints

- No SDRAM, and no free FPGA pins to add one. Memory is the HPS DDR3 (512 MB) through
  `DDRAM_*` (f2sdram).
- DDR3 window available to cores: `0x10000000-0x1CFFFFFF`. The MiSTer framebuffer is at
  `0x1D000000` and the scaler buffer at `0x1E800000`.
- Video: RGB565 to a TDA19988 HDMI transmitter. Audio: I2S to HDMI. No VGA, analog
  audio, ALSA, SDIO or USER_IO.
- Clocks: no FPGA oscillator; 50 MHz comes from the HPS (`h2f_user1_clk`).

## To do (port)

1. `platform/ch96/ddram_ctrl.sv`: DDR3 backend for `sdram_arbiter` (replaces `sdram_ctrl`).
2. Share the single `DDRAM_*` port between the core RAM and the 350-line frame capture
   (`ega_ddr_arbiter`).
3. Move the frame capture base (`ega_fb_capture`/`ega_fb_readout`, `BASE_ADDR` 29'h6000000 =
   0x30000000) into the ch96 window.
4. Video memory (CGA/HGC/EGA) back to BRAM, with a BRAM mirror of the Tandy/PCjr video RAM
   fed by the write snoop, so video never waits on DDR3 latency.
5. Re-apply the PCXT `sys/` fixes that teiram's framework lacks if still needed (ascal `mode`
   width: Critical Warning "4 elements where 5 expected"; ascal output recovery at vsync).
6. `files.qip`: board-specific memory backend instead of `platform/mister/sdram_ctrl.sv`.
7. `SYSTEM.sdc`: its paths are relative to `sys_top` (`emu|...`, `emu:emu|...`, `pll_hdmi|...`,
   `sysmem|...`); under `ch96_top` they need the `sys_top|` prefix, and the SDRAM I/O
   constraints go away.
