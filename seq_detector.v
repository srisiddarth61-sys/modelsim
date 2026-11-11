// 2.1 Sequence Detector: overlapping "1011", Mealy FSM, synchronous active-high reset
module seq_detector (
    input  wire clk, rst, din,
    output wire detect
);
    localparam S0 = 2'd0,   // no useful prefix
               S1 = 2'd1,   // seen "1"
               S2 = 2'd2,   // seen "10"
               S3 = 2'd3;   // seen "101"
    reg [1:0] state, next;
    always @(posedge clk) state <= rst ? S0 : next;
    always @* begin
        case (state)
            S0: next = din ? S1 : S0;
            S1: next = din ? S1 : S2;
            S2: next = din ? S3 : S0;
            S3: next = din ? S1 : S2;   // "1011" done: trailing 1 is a new prefix; "1010" keeps "10"
            default: next = S0;
        endcase
    end
    assign detect = (state == S3) & din;  // Mealy output
endmodule
