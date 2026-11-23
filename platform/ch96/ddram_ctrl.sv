//
// DDR3 backend for the Chameleon96 (no SDRAM on that board).
//
// Drop-in replacement for platform/mister/sdram_ctrl.sv: it takes the same
// operations from sdram_arbiter (op_* holding register) and returns read words
// the same way (rd_*, in issue order, one 16-bit word per clock), but executes
// them on the HPS DDR3 through the f2sdram Avalon port (DDRAM_*).
//
// Mapping: the 24-bit word address of the core (32 MiB) is placed at byte
// address BASE of the DDR3. Four 16-bit words share one 64-bit Avalon word;
// an operation of 1, 2 or 4 words starting at word w covers one or two
// consecutive Avalon words, so it becomes one Avalon burst of 1 or 2 beats.
//
// Ordering: every operation goes out on the same Avalon port in the order the
// arbiter issued it, and the port keeps that order (a read issued after a write
// sees the write). A write is therefore complete for the arbiter as soon as it
// is taken, exactly as with the SDRAM controller.
//
// Reads are pipelined: up to MAXQ of them may be in flight. Their beats are
// buffered and handed back as words; rd_valid can have gaps if the second beat
// of a burst is late, which the clients accept (they count rvalid/rlast).
//
// Refresh operations are taken and dropped: the HPS controller refreshes.
// bank_idle is always all ones: there are no banks to wait for here.
//
module ddram_ctrl #(
    parameter logic [31:0] BASE = 32'h1100_0000,   // byte address in DDR3
    parameter int          MAXQ = 8                // reads in flight (power of 2)
) (
    input  logic        clk,
    input  logic        reset,
    output logic        init_done,

    // Operation from the arbiter. Held, unchanged, until op_issue.
    input  logic        op_valid,
    input  logic        op_ref,
    input  logic        op_we,
    input  logic [23:0] op_addr,      // 16-bit words
    input  logic [1:0]  op_len,       // sdram_pkg::LEN_*
    input  logic [63:0] op_wdata,
    input  logic [7:0]  op_wbe,
    input  logic [1:0]  op_tag,
    output logic        op_issue,
    output logic [3:0]  bank_idle,

    // Read words, in the order the reads were issued.
    output logic        rd_valid,
    output logic [15:0] rd_data,
    output logic [1:0]  rd_tag,
    output logic        rd_last,

    // f2sdram Avalon port
    input  logic        ddram_busy,
    output logic [7:0]  ddram_burstcnt,
    output logic [28:0] ddram_addr,
    input  logic [63:0] ddram_dout,
    input  logic        ddram_dout_ready,
    output logic        ddram_rd,
    output logic [63:0] ddram_din,
    output logic [7:0]  ddram_be,
    output logic        ddram_we
);

    localparam logic [28:0] BASE_W = BASE[31:3];
    localparam int QW = $clog2(MAXQ);
    localparam int BD = 2 * MAXQ;               // beat buffer depth
    localparam int BW = $clog2(BD);

    assign bank_idle = 4'b1111;

    // ------------------------------------------------------------------
    // Start-up: a few clocks after reset
    // ------------------------------------------------------------------
    logic [4:0] init_cnt;
    always_ff @(posedge clk) begin
        if (reset) begin
            init_cnt  <= 5'd0;
            init_done <= 1'b0;
        end
        else if (!init_done) begin
            init_cnt  <= init_cnt + 5'd1;
            init_done <= &init_cnt;
        end
    end

    // ------------------------------------------------------------------
    // Request side
    // ------------------------------------------------------------------
    logic        wr2_pending;    // second beat of a write burst still to send
    logic [63:0] wr2_data;
    logic [7:0]  wr2_be;
    logic [QW:0] rq_count;       // reads issued and not yet fully returned
    logic        rq_done;        // a read finishes returning on this edge

    // The Avalon request register is free on this edge.
    wire av_free = ~(ddram_rd | ddram_we) | ~ddram_busy;

    // Decode of the held operation.
    wire [1:0] w0     = op_addr[1:0];
    wire [2:0] nwords = sdram_pkg::len_words(op_len);
    wire [2:0] wlast  = {1'b0, w0} + nwords - 3'd1;      // 0..6
    wire       two    = wlast[2];

    // Operations taken from the arbiter wait in a two-entry queue in front of
    // the Avalon register, so that op_issue depends on registers only and not
    // on the HPS waitrequest (it feeds the arbiter's grant logic).
    logic        q_we  [2];
    logic        q_two [2];
    logic [21:0] q_a   [2];
    logic [63:0] q_d0  [2], q_d1 [2];
    logic [7:0]  q_b0  [2], q_b1 [2];
    logic [1:0]  q_wp, q_rp;             // one extra bit: full/empty
    wire         q_full  = (q_wp[0] == q_rp[0]) & (q_wp[1] != q_rp[1]);
    wire         q_empty = (q_wp == q_rp);

    wire can_take = init_done & ~q_full & (op_we | (rq_count != (QW+1)'(MAXQ)));

    assign op_issue = op_valid & (op_ref | can_take);
    wire take = op_valid & ~op_ref & can_take;

    // Write data and byte enables placed in a 128-bit window.
    logic [7:0]   wbe_n;
    logic [127:0] wdata_sh;
    logic [15:0]  wbe_sh;
    always_comb begin
        case (nwords)
            3'd1:    wbe_n = op_wbe & 8'h03;
            3'd2:    wbe_n = op_wbe & 8'h0F;
            default: wbe_n = op_wbe;
        endcase
        wdata_sh = {64'd0, op_wdata} << (16 * w0);
        wbe_sh   = {8'd0, wbe_n} << (2 * w0);
    end

    // Read descriptors, in issue order.
    logic [1:0] rq_tag  [MAXQ];
    logic [1:0] rq_w0   [MAXQ];
    logic [2:0] rq_n    [MAXQ];
    logic [QW:0]   rq_wp, rq_rp;       // one extra bit: full/empty

    always_ff @(posedge clk) begin
        if (take) begin
            q_we[q_wp[0]]  <= op_we;
            q_two[q_wp[0]] <= two;
            q_a[q_wp[0]]   <= op_addr[23:2];
            q_d0[q_wp[0]]  <= wdata_sh[63:0];
            q_d1[q_wp[0]]  <= wdata_sh[127:64];
            q_b0[q_wp[0]]  <= op_we ? wbe_sh[7:0] : 8'hFF;
            q_b1[q_wp[0]]  <= wbe_sh[15:8];
        end
        if (take && !op_we) begin
            rq_tag[rq_wp[QW-1:0]] <= op_tag;
            rq_w0[rq_wp[QW-1:0]]  <= w0;
            rq_n[rq_wp[QW-1:0]]   <= nwords;
        end
    end

    // Queue head -> Avalon
    wire send = ~q_empty & av_free & ~wr2_pending;

    always_ff @(posedge clk) begin
        if (reset) begin
            ddram_rd    <= 1'b0;
            ddram_we    <= 1'b0;
            ddram_addr  <= 29'd0;
            ddram_burstcnt <= 8'd1;
            ddram_din   <= 64'd0;
            ddram_be    <= 8'd0;
            wr2_pending <= 1'b0;
            rq_wp       <= '0;
            q_wp        <= 2'd0;
            q_rp        <= 2'd0;
        end
        else begin
            if (take)            q_wp  <= q_wp + 2'd1;
            if (take && !op_we)  rq_wp <= rq_wp + 1'd1;

            if (!ddram_busy) begin
                ddram_rd <= 1'b0;
                ddram_we <= 1'b0;
            end

            if (wr2_pending && av_free) begin
                // Second beat of the burst write started on the previous transfer.
                ddram_we    <= 1'b1;
                ddram_din   <= wr2_data;
                ddram_be    <= wr2_be;
                wr2_pending <= 1'b0;
            end
            else if (send) begin
                q_rp           <= q_rp + 2'd1;
                ddram_addr     <= BASE_W + {7'd0, q_a[q_rp[0]]};
                ddram_burstcnt <= q_two[q_rp[0]] ? 8'd2 : 8'd1;
                ddram_din      <= q_d0[q_rp[0]];
                ddram_be       <= q_b0[q_rp[0]];
                if (q_we[q_rp[0]]) begin
                    ddram_we    <= 1'b1;
                    wr2_pending <= q_two[q_rp[0]];
                    wr2_data    <= q_d1[q_rp[0]];
                    wr2_be      <= q_b1[q_rp[0]];
                end
                else
                    ddram_rd    <= 1'b1;
            end
        end
    end

    wire rd_taken = take & ~op_we;

    always_ff @(posedge clk) begin
        if (reset)
            rq_count <= '0;
        else
            rq_count <= rq_count + (QW+1)'(rd_taken) - (QW+1)'(rq_done);
    end

    // ------------------------------------------------------------------
    // Return side: beats -> buffer -> words
    // ------------------------------------------------------------------
    logic [63:0]   bbuf [BD];
    logic [BW:0]   b_wp, b_rp;           // one extra bit: full/empty
    wire           b_empty = (b_wp == b_rp);
    wire  [63:0]   b_head  = bbuf[b_rp[BW-1:0]];
    logic          b_pop;

    always_ff @(posedge clk) begin
        if (ddram_dout_ready)
            bbuf[b_wp[BW-1:0]] <= ddram_dout;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            b_wp <= '0;
            b_rp <= '0;
        end
        else begin
            if (ddram_dout_ready) b_wp <= b_wp + 1'd1;
            if (b_pop)            b_rp <= b_rp + 1'd1;
        end
    end

    // Word serializer
    logic       s_act;        // a read is being returned
    logic [1:0] s_idx;        // word inside the current beat
    logic [2:0] s_left;       // words still to return
    logic [1:0] s_tag;

    wire rq_avail = ~s_act & (rq_rp != rq_wp);
    wire s_word   = s_act & ~b_empty;
    wire s_end    = s_word & (s_left == 3'd1);

    assign b_pop   = s_word & ((s_idx == 2'd3) | (s_left == 3'd1));
    assign rq_done = s_end;

    always_ff @(posedge clk) begin
        if (reset) begin
            s_act    <= 1'b0;
            s_idx    <= 2'd0;
            s_left   <= 3'd0;
            s_tag    <= 2'd0;
            rq_rp    <= '0;
            rd_valid <= 1'b0;
            rd_last  <= 1'b0;
            rd_data  <= 16'd0;
            rd_tag   <= 2'd0;
        end
        else begin
            rd_valid <= 1'b0;
            rd_last  <= 1'b0;

            if (rq_avail) begin
                s_act  <= 1'b1;
                s_idx  <= rq_w0[rq_rp[QW-1:0]];
                s_left <= rq_n[rq_rp[QW-1:0]];
                s_tag  <= rq_tag[rq_rp[QW-1:0]];
                rq_rp  <= rq_rp + 1'd1;
            end
            else if (s_word) begin
                rd_valid <= 1'b1;
                rd_last  <= (s_left == 3'd1);
                rd_data  <= b_head[16 * s_idx +: 16];
                rd_tag   <= s_tag;
                s_idx    <= s_idx + 2'd1;
                s_left   <= s_left - 3'd1;
                if (s_left == 3'd1)
                    s_act <= 1'b0;
            end
        end
    end

endmodule
