# platform/ch96

Board-specific memory backend for the Chameleon96. The board has no SDRAM; the
core's RAM will live in the HPS DDR3 through the f2sdram port (`DDRAM_*`), which
is free on this board because the 350-line CRT conversion is not used.

Planned contents:
- `ddram_ctrl.sv`: implements the `op_*` interface that `sdram_arbiter` drives
  today (see `platform/mister/sdram_ctrl.sv`) on top of the Avalon `DDRAM_*` bus,
  at byte address `0x11000000` and up.

Not started yet. Until it exists, the core builds but has no working RAM.
