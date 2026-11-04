`timescale 1ns/1ps

// 2:1 Multiplexer
// sel = 0 -> y = a
// sel = 1 -> y = b
module mux2to1 (
    input  wire a,
    input  wire b,
    input  wire sel,
    output wire y
);

    assign y = sel ? b : a;

endmodule
