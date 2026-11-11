// 2.2 Vending Machine Controller: item price 15 cents, accepts nickel(5)/dime(10), Moore FSM
module vending (
    input  wire clk, rst,
    input  wire nickel, dime,       // one coin per cycle (both high = invalid, ignored)
    output wire dispense,           // 1-cycle pulse
    output wire change              // 1-cycle pulse: return a nickel (5c)
);
    localparam C0=3'd0, C5=3'd1, C10=3'd2, VEND=3'd3, VEND_CHG=3'd4;
    reg [2:0] state, next;
    wire coin_n = nickel & ~dime, coin_d = dime & ~nickel;
    always @(posedge clk) state <= rst ? C0 : next;
    always @* begin
        next = state;
        case (state)
            C0:  if (coin_n) next = C5;   else if (coin_d) next = C10;
            C5:  if (coin_n) next = C10;  else if (coin_d) next = VEND;       // 15
            C10: if (coin_n) next = VEND; else if (coin_d) next = VEND_CHG;   // 20
            VEND, VEND_CHG: next = C0;     // coins ignored while dispensing
            default: next = C0;
        endcase
    end
    assign dispense = (state == VEND) | (state == VEND_CHG);   // Moore outputs
    assign change   = (state == VEND_CHG);
endmodule
