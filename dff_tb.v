`timescale 1ns/1ps

module dff_tb;
    reg  clk, rst, d;
    wire q;

    dff uut (.clk(clk), .rst(rst), .d(d), .q(q));

    always #5 clk = ~clk;

    initial begin
        $monitor("t=%0t | rst=%b d=%b | q=%b", $time, rst, d, q);
        clk = 0; rst = 1; d = 0;
        #12 rst = 0;
        #10 d = 1;
        #10 d = 0;
        #10 d = 1;
        #10 rst = 1;
        #10 rst = 0; d = 0;
        #20 $finish;
    end
endmodule