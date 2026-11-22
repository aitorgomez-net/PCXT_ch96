# platform/ch96

Board-specific memory backend for the Chameleon96. The board has no SDRAM; the
core's RAM will live in the HPS DDR3 through the f2sdram port (`DDRAM_*`).

Planned contents:
- `ddram_ctrl.sv`: implements the `op_*` interface that `sdram_arbiter` drives
  today (see `platform/mister/sdram_ctrl.sv`) on top of the Avalon `DDRAM_*` bus.

Not started yet. Until it exists, the core builds but has no working RAM.
