`timescale 1ns/1ps
module sync_fifo_tb;
    parameter DW = 8, DEPTH = 16;
    reg clk=0, rst=1, wr_en=0, rd_en=0; reg [DW-1:0] wdata=0;
    wire [DW-1:0] rdata; wire rvalid, full, empty, overflow, underflow; wire [$clog2(DEPTH):0] count;
    sync_fifo #(DW,DEPTH) dut(clk,rst,wr_en,wdata,rd_en,rdata,rvalid,full,empty,count,overflow,underflow);
    always @(posedge clk) ; always #5 clk=~clk;
    // scoreboard / reference model
    reg [DW-1:0] mmem [0:DEPTH-1]; integer mw=0, mr=0, mcount=0;
    reg exp_rvalid=0, exp_ovf=0, exp_unf=0; reg [DW-1:0] exp_rdata=0; reg check_en=0;
    integer errors=0, cycles=0, writes=0, reads=0, ovfs=0, unfs=0, i;
    reg mdo_wr, mdo_rd;
    always @(posedge clk) begin
        if (rst) begin mw=0; mr=0; mcount=0; exp_rvalid=0; exp_ovf=0; exp_unf=0; check_en=1; end
        else if (check_en) begin
            cycles = cycles + 1;
            if (full !== (mcount==DEPTH) || empty !== (mcount==0) || count !== mcount ||
                overflow !== exp_ovf || underflow !== exp_unf || rvalid !== exp_rvalid ||
                (exp_rvalid && rdata !== exp_rdata)) begin
                errors = errors + 1;
                $display("FAIL t=%0t count=%0d(exp %0d) full=%b empty=%b ovf=%b/%b unf=%b/%b rvalid=%b/%b rdata=%h(exp %h)",
                    $time,count,mcount,full,empty,overflow,exp_ovf,underflow,exp_unf,rvalid,exp_rvalid,rdata,exp_rdata);
            end
            if (overflow) ovfs = ovfs + 1; if (underflow) unfs = unfs + 1;
            mdo_wr = wr_en && mcount < DEPTH;  mdo_rd = rd_en && mcount > 0;
            exp_ovf = wr_en && mcount == DEPTH;  exp_unf = rd_en && mcount == 0;
            exp_rvalid = mdo_rd;
            if (mdo_rd) begin exp_rdata = mmem[mr]; mr = (mr+1) % DEPTH; mcount = mcount - 1; reads = reads + 1; end
            if (mdo_wr) begin mmem[mw] = wdata; mw = (mw+1) % DEPTH; mcount = mcount + 1; writes = writes + 1; end
        end
    end
    task cyc(input w, input r, input [DW-1:0] d); begin @(negedge clk); wr_en=w; rd_en=r; wdata=d; end endtask
    integer pw;
    initial begin
        $dumpfile("fifo.vcd"); $dumpvars(0, sync_fifo_tb);
        repeat(2) @(negedge clk); rst=0;
        // 1) underflow on empty
        cyc(0,1,0); cyc(0,0,0);
        // 2) fill completely, then overflow attempts
        for (i=0;i<DEPTH;i=i+1) cyc(1,0,i+8'hA0);
        cyc(1,0,8'hEE); cyc(1,1,8'hEF);       // write rejected at full (read accepted)
        cyc(0,0,0);
        // 3) drain completely, then underflow
        for (i=0;i<DEPTH+2;i=i+1) cyc(0,1,0);
        cyc(0,0,0);
        // 4) simultaneous read+write in the middle (data should flow through in order)
        for (i=0;i<DEPTH/2;i=i+1) cyc(1,0,i+8'h10);
        for (i=0;i<DEPTH*2;i=i+1) cyc(1,1,i+8'h40);
        // 5) random phases: write-heavy, balanced, read-heavy, with a mid-test reset
        for (pw=80; pw>=20; pw=pw-30) begin
            for (i=0;i<1500;i=i+1) cyc(($urandom%100)<pw, ($urandom%100)<(100-pw), $random);
        end
        @(negedge clk); rst=1; @(negedge clk); rst=0;
        for (i=0;i<500;i=i+1) cyc($random, $random, $random);
        cyc(0,0,0); cyc(0,0,0); cyc(0,0,0);
        $display("SYNC_FIFO TEST (DATA_W=%0d DEPTH=%0d): %0d cycles, %0d writes, %0d reads, %0d overflow pulses, %0d underflow pulses, %0d errors -> %s",
                 DW,DEPTH,cycles,writes,reads,ovfs,unfs,errors,errors==0?"PASS":"FAIL");
        $finish;
    end
endmodule
