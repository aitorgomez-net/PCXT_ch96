# platform/ch96

Board-specific memory backend for the Chameleon96. The core's RAM lives in the
HPS DDR3 through the f2sdram port (`DDRAM_*`).

- `ddram_ctrl.sv`: implements the `op_*` / `rd_*` interface that `sdram_arbiter`
  drives, on top of the Avalon
  `DDRAM_*` bus. The core's 32 MiB word space starts at byte address
  `0x11000000`. Each operation (1, 2 or 4 words) becomes one Avalon burst of one
  or two 64-bit beats; up to 8 reads are in flight and their words come back in
  order. Refreshes are dropped (the HPS controller refreshes the DDR3).

Selected in `PCXT.sv` under `MISTER_CHAMELEON96`.
