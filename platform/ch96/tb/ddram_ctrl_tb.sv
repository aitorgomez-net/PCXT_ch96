// Random-operation test of ddram_ctrl against an in-order Avalon model.
// iverilog -g2012 ../../../rtl/mem/sdram_pkg.sv ../ddram_ctrl.sv ddram_ctrl_tb.sv && vvp a.out
`timescale 1ns/1ps
module tb #(parameter int MAXQ = 8);
  logic clk=0, reset=1; always #4 clk=~clk;
  logic init_done, op_valid=0, op_ref=0, op_we=0; logic [23:0] op_addr=0; logic [1:0] op_len=0;
  logic [63:0] op_wdata=0; logic [7:0] op_wbe=0; logic [1:0] op_tag=0; wire op_issue; wire [3:0] bank_idle;
  wire rd_valid, rd_last; wire [15:0] rd_data; wire [1:0] rd_tag;
  logic busy; wire [7:0] bc; wire [28:0] aa; logic [63:0] dout; logic dready; wire rd, we; wire [63:0] din; wire [7:0] be;
  ddram_ctrl #(.BASE(32'h11000000), .MAXQ(MAXQ)) dut(.clk, .reset, .init_done, .op_valid, .op_ref, .op_we, .op_addr, .op_len,
    .op_wdata, .op_wbe, .op_tag, .op_issue, .bank_idle, .rd_valid, .rd_data, .rd_tag, .rd_last,
    .ddram_busy(busy), .ddram_burstcnt(bc), .ddram_addr(aa), .ddram_dout(dout), .ddram_dout_ready(dready),
    .ddram_rd(rd), .ddram_din(din), .ddram_be(be), .ddram_we(we));

  // Avalon memory, 64-bit words, index relative to base
  logic [63:0] amem [0:1023];
  logic [15:0] ref_mem [0:4095];
  // read return queue (beats)
  logic [63:0] rq [$]; int rlat [$];
  int wburst_left=0; int waddr;
  int errors=0, nreads=0, nwrites=0;
  initial for (int i=0;i<1024;i++) amem[i]=0;
  initial for (int i=0;i<4096;i++) ref_mem[i]=0;

  always @(posedge clk) busy <= ($urandom%4==0);
  int cycle=0;
  always @(posedge clk) begin
    cycle++;
    dready <= 0;
    if (!reset && !busy) begin
      if (rd) begin : rdb
        int a; a = aa - 29'h2200000;
        if (a<0 || a+bc>1024) begin $display("ADDR ERR %h",aa); errors++; end
        for (int k=0;k<bc;k++) begin rq.push_back(amem[a+k]); rlat.push_back(cycle + 3 + $urandom%30); end
        if (wburst_left) begin $display("rd during wburst"); errors++; end
      end
      if (we) begin : web
        int a;
        if (wburst_left==0) begin a = aa - 29'h2200000; wburst_left = bc; waddr=a; end
        for (int b=0;b<8;b++) if (be[b]) amem[waddr][8*b+:8] = din[8*b+:8];
        waddr++; wburst_left--;
      end
    end
    // in-order return, at most one beat per clock, respecting latency (monotone)
    if (rq.size() && rlat[0] <= cycle) begin dready<=1; dout<=rq.pop_front(); void'(rlat.pop_front()); end
  end

  // expected reads
  logic [15:0] exp_w [$]; logic [1:0] exp_t [$]; logic exp_l [$];
  always @(posedge clk) if (rd_valid) begin
    if (exp_w.size()==0) begin $display("unexpected word"); errors++; end
    else begin : chk
      logic [15:0] w; logic [1:0] t; logic l; w=exp_w.pop_front(); t=exp_t.pop_front(); l=exp_l.pop_front();
      if (w!==rd_data || t!==rd_tag || l!==rd_last) begin errors++; if (errors<20) $display("MISMATCH t=%0t got %h/%0d/%0d exp %h/%0d/%0d",$time,rd_data,rd_tag,rd_last,w,t,l); end
    end
  end

  initial begin
    repeat(5) @(posedge clk); reset=0;
    wait(init_done);
    for (int n=0;n<20000;n++) begin
      @(posedge clk);
      if ($urandom%3==0) repeat(1) @(posedge clk);
      op_valid<=1; op_ref <= (($urandom%20)==0);
      op_we <= $urandom%2; op_len <= $urandom%3; op_addr <= $urandom%4090; op_wdata <= {$urandom,$urandom}; op_wbe <= $urandom; op_tag <= $urandom;
      #1;
      do @(posedge clk); while (!op_issue);
      // model at issue edge
      if (!op_ref) begin : mdl
        int nw; nw = (op_len==0)?1:(op_len==1)?2:4;
        for (int i=0;i<nw;i++) begin
          if (op_we) begin
            if (op_wbe[2*i]) ref_mem[op_addr+i][7:0] = op_wdata[16*i+:8];
            if (op_wbe[2*i+1]) ref_mem[op_addr+i][15:8] = op_wdata[16*i+8+:8];
          end else begin exp_w.push_back(ref_mem[op_addr+i]); exp_t.push_back(op_tag); exp_l.push_back(i==nw-1); end
        end
        if (op_we) nwrites++; else nreads++;
      end
      op_valid<=0;
    end
    repeat(500) @(posedge clk);
    $display("reads=%0d writes=%0d errors=%0d left=%0d", nreads, nwrites, errors, exp_w.size());
    $finish;
  end
endmodule
