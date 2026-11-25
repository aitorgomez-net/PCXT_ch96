//============================================================================
//
//  PCXT MiSTer boot splash ROM
//
//  One 320x200, 16-colour picture for every card: splash_320x200.hex, two
//  4-bit RGBI pixels per byte, the left one in bits 7:4, 160 bytes per line
//  (SW/make_splash_rom.py builds it).  The Chameleon96 build loads
//  splash_320x200_ch96.hex instead: the same picture with "ch96" in place of
//  "MiSTer" in the logo.  Two read ports on one clock: port A
//  feeds the CGA renderer, port B the EGA one.  A build with a single card
//  leaves the other port unused and the ROM collapses to a single port.
//
//  Both reads sit in one always block and neither has an enable: written that
//  way Quartus 17 builds one true dual-port M10K ROM.  With an enable on one
//  port, or one always block per port, it builds two single-port copies.
//
//============================================================================

`default_nettype wire

module splash_rom (
    input  wire        clk,
    input  wire [14:0] addr_a,
    output reg  [7:0]  q_a,
    input  wire [14:0] addr_b,
    output reg  [7:0]  q_b
);

    localparam integer SPLASH_ROM_SIZE = 160 * 200;

    (* ramstyle = "M10K" *) reg [7:0] rom [0:32767];

    initial begin
`ifdef MISTER_CHAMELEON96
        $readmemh("splash_320x200_ch96.hex", rom, 0, SPLASH_ROM_SIZE-1);
`else
        $readmemh("splash_320x200.hex", rom, 0, SPLASH_ROM_SIZE-1);
`endif
    end

    always @(posedge clk) begin
        q_a <= rom[addr_a];
        q_b <= rom[addr_b];
    end

endmodule
