//
// Fixed delay line for the outputs of a CRTC (MA, RA, DE, cursor, syncs,
// blanking), in clocks of the card.
//
// Why: the card reads each character's word from the video fetch engine at
// fixed slots, and the engine can only ask for it once the CRTC knows its
// address, which is one character ahead (MA_NEXT). On a memory with a long
// and irregular latency (the HPS DDR3 of the Chameleon96, shared with the
// scaler and Linux) one character is not always enough, and a late word shows
// up as a wrong glyph. With this delay the card draws from MA/RA/DE/... as
// they were LEN clocks ago, while the requests still follow the undelayed
// MA_NEXT, so each word is asked for LEN clocks earlier than it is needed.
//
// LEN must be a whole number of characters and of sequencer cycles, so that
// every delayed output keeps its phase against the sequencer of the card
// (the sequencer itself is not delayed). Everything that leaves the card
// (syncs, blanking, status register) comes from the delayed copies, so the
// picture is simply LEN clocks later; nothing moves on the screen.
//
// A circular buffer in block RAM: the word written at clock t is read back
// at clock t + LEN. LEN may change at run time (a mode change): the output is
// then wrong for one delay's worth of clocks.
//
module crtc_delay #(
    parameter int W  = 32,          // bits per clock
    parameter int AW = 7            // log2 of the buffer depth: LEN < 2**AW
) (
    input  logic          clk,
    input  logic [AW-1:0] len,      // delay in clocks, 2 .. 2**AW - 1
    input  logic [W-1:0]  d,
    output logic [W-1:0]  q
);
    logic [W-1:0]  mem [0:(1 << AW) - 1];
    logic [AW-1:0] wp = '0;

    initial begin
        for (int i = 0; i < (1 << AW); i++) mem[i] = '0;
        q = '0;
    end

    // Read the word written len-1 clocks ago; the read is registered, which
    // adds the last clock. Read and write addresses always differ (len >= 2).
    wire [AW-1:0] rp = wp - len + 1'b1;

    always_ff @(posedge clk) begin
        mem[wp] <= d;
        q       <= mem[rp];
        wp      <= wp + 1'b1;
    end

endmodule
