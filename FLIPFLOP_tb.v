
module tb_d_flipflop;

reg d;
reg clk;
wire q;

d_flipflop uut (
    .d(d),
    .clk(clk),
    .q(q)
);

always #5 clk = ~clk;

initial
begin
    clk = 0;
    d = 0;

    #10 d = 1;
    #10 d = 0;
    #10 d = 1;
    #10 d = 0;

    #10 $finish;
end

initial
begin
    $monitor("Time=%0t d=%b clk=%b q=%b",
             $time, d, clk, q);
end

endmodule
