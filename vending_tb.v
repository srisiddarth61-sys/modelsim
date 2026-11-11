`timescale 1ns/1ps
module vending_tb;
    reg clk=0, rst=1, nickel=0, dime=0; wire dispense, change;
    vending dut(clk,rst,nickel,dime,dispense,change);
    always #5 clk=~clk;
    // behavioural reference model (running total in cents), independent of the FSM encoding
    integer tot = 0; reg pend_d = 0, pend_c = 0, check_en = 0;
    integer errors=0, cycles=0, n_disp=0, n_chg=0, i, tn;
    wire coin_valid = nickel ^ dime; integer coin_val; 
    always @(posedge clk) begin
        coin_val = nickel ? 5 : 10;
        if (rst) begin tot=0; pend_d=0; pend_c=0; check_en=1; end
        else if (check_en) begin
            cycles = cycles + 1;
            if (dispense !== pend_d || change !== pend_c) begin
                errors=errors+1; $display("FAIL t=%0t disp=%b(exp %b) chg=%b(exp %b)",$time,dispense,pend_d,change,pend_c);
            end
            if (dispense) n_disp = n_disp + 1;  if (change) n_chg = n_chg + 1;
            if (pend_d) begin tot=0; pend_d=0; pend_c=0; end         // dispensing cycle: coins ignored
            else if (coin_valid) begin
                tn = tot + coin_val;
                if (tn >= 15) begin pend_d = 1; pend_c = (tn == 20); end
                tot = tn;
            end
        end
    end
    task coin(input is_dime); begin @(negedge clk); nickel = ~is_dime; dime = is_dime; @(negedge clk); nickel=0; dime=0; end endtask
    task idle(input integer n); begin repeat(n) @(negedge clk); end endtask
    initial begin
        $dumpfile("vending.vcd"); $dumpvars(0, vending_tb);
        repeat(2) @(negedge clk); rst=0;
        coin(0); coin(0); coin(0); idle(3);   // N N N  -> vend, no change
        coin(1); coin(0);          idle(3);   // D N    -> vend, no change
        coin(0); coin(1);          idle(3);   // N D    -> vend, no change
        coin(1); coin(1);          idle(3);   // D D    -> vend + change
        $display("directed: dispenses=%0d (expect 4) changes=%0d (expect 1)", n_disp, n_chg);
        if (n_disp != 4 || n_chg != 1) errors = errors + 1;
        // both coin inputs high is invalid -> ignored
        @(negedge clk); nickel=1; dime=1; @(negedge clk); @(negedge clk); nickel=0; dime=0; idle(2);
        // coin arriving in the dispensing cycle is ignored (by design)
        coin(1); @(negedge clk); nickel=0; dime=1; @(negedge clk); nickel=1; dime=0; @(negedge clk); nickel=0; idle(4);
        // random traffic with occasional reset
        for (i=0;i<4000;i=i+1) begin
            @(negedge clk); nickel=$random; dime=$random; rst = ($urandom%400==0);
        end
        @(negedge clk); rst=0; nickel=0; dime=0; idle(3);
        $display("VENDING TEST: %0d cycles, %0d dispenses, %0d change, %0d errors -> %s",cycles,n_disp,n_chg,errors,errors==0?"PASS":"FAIL");
        $finish;
    end
endmodule
