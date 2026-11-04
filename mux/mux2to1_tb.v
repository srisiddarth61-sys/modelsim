`timescale 1ns/1ps

module mux2to1_tb;

    reg  a, b, sel;
    wire y;

    reg  expected;
    integer i;

    mux2to1 uut (
        .a(a),
        .b(b),
        .sel(sel),
        .y(y)
    );

    initial begin
        $display("==========================================");
        $display("         2:1 MULTIPLEXER SIMULATION");
        $display("==========================================");
        $display("  sel   b   a   |   y   Expected   Status");
        $display("------------------------------------------");

        // Try all 8 combinations of {sel, b, a}
        for (i = 0; i < 8; i = i + 1) begin
            {sel, b, a} = i[2:0];
            #10;

            expected = sel ? b : a;

            if (y === expected)
                $display("   %b    %b   %b   |   %b      %b        PASS", sel, b, a, y, expected);
            else
                $display("   %b    %b   %b   |   %b      %b        FAIL", sel, b, a, y, expected);
        end

        $display("==========================================");
        $display("          SIMULATION COMPLETED");
        $display("==========================================");

        $stop;
    end

endmodule
