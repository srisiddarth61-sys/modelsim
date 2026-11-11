`timescale 1ns/1ps
module seq_detector_tb;
    reg clk=0, rst=1, din=0; wire detect;
    seq_detector dut(clk,rst,din,detect);
    always #5 clk = ~clk;
    // reference model: 4-bit shift register of the last inputs
    reg [3:0] sh = 0; reg exp_detect; reg check_en = 0;
    integer errors=0, cycles=0, hits=0, i;
    always @(posedge clk) begin           // sample pre-edge values
        if (rst) begin sh = 0; check_en = 1; end
        else if (check_en) begin
            cycles = cycles + 1;
            exp_detect = ({sh[2:0], din} == 4'b1011);
            if (detect !== exp_detect) begin
                errors = errors + 1; $display("FAIL t=%0t din=%b detect=%b exp=%b", $time, din, detect, exp_detect);
            end
            if (detect) hits = hits + 1;
            sh = {sh[2:0], din};
        end
    end
    task send(input [15:0] bits, input integer n); integer k; begin
        for (k=n-1;k>=0;k=k-1) begin @(negedge clk); din = bits[k]; end
    end endtask
    integer hits_before;
    initial begin
        $dumpfile("seq.vcd"); $dumpvars(0, seq_detector_tb);
        repeat (2) @(negedge clk); rst = 0;
        // directed 1: overlapping occurrences  1011011 -> exactly 2 hits
        hits_before = hits; send(16'b0000_0000_0101_1011, 8); send(16'b0, 2);
        @(negedge clk); @(negedge clk);
        $display("directed overlap stream 01011011 -> hits=%0d (expect 2)", hits-hits_before);
        if (hits-hits_before != 2) errors = errors + 1;
        // directed 2: near misses must not fire
        hits_before = hits; send(16'b1010_1010_0110_0111, 16); send(16'b0, 2);
        @(negedge clk);
        $display("directed near-miss stream -> hits=%0d (expect 0)", hits-hits_before);
        if (hits-hits_before != 0) errors = errors + 1;
        // reset in the middle of a pattern: 101 | rst | 1 must NOT fire
        hits_before = hits; send(5'b101, 3); @(negedge clk); rst = 1; din = 0; @(negedge clk); rst = 0; send(1'b1, 1); send(16'b0,2);
        @(negedge clk);
        $display("reset mid-pattern -> hits=%0d (expect 0)", hits-hits_before);
        if (hits-hits_before != 0) errors = errors + 1;
        // random stream
        for (i=0;i<3000;i=i+1) begin @(negedge clk); din = $random; if ($urandom%500==0) rst=1; else rst=0; end
        @(negedge clk); @(negedge clk);
        $display("SEQ_DETECTOR TEST: %0d cycles, %0d detections, %0d errors -> %s", cycles, hits, errors, errors==0?"PASS":"FAIL");
        $finish;
    end
endmodule
