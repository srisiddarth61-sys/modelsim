module atm_controller (
    input wire clk,
    input wire reset,
    input wire card_inserted,
    input wire pin_valid,
    input wire pin_invalid,
    input wire req_withdraw,
    input wire req_balance,
    input wire cancel,
    input wire dispense_done,

    output reg prompt_pin,
    output reg show_menu,
    output reg dispensing,
    output reg show_balance,
    output reg ejecting
);

    
    parameter IDLE     = 3'b000,
              WAIT_PIN = 3'b001,
              OPTIONS  = 3'b010,
              DISPENSE = 3'b011,
              BALANCE  = 3'b100,
              EJECT    = 3'b101;

    reg [2:0] state, next_state;

    
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    
    always @(*) begin
        next_state = state;

        case (state)
            IDLE:
                if (card_inserted)
                    next_state = WAIT_PIN;

            WAIT_PIN:
                if (pin_valid)
                    next_state = OPTIONS;
                else if (pin_invalid || cancel)
                    next_state = EJECT;

            OPTIONS:
                if (req_withdraw)
                    next_state = DISPENSE;
                else if (req_balance)
                    next_state = BALANCE;
                else if (cancel)
                    next_state = EJECT;

            DISPENSE:
                if (dispense_done)
                    next_state = EJECT;

            BALANCE:
                if (cancel)
                    next_state = OPTIONS;

            EJECT:
                if (!card_inserted)
                    next_state = IDLE;

            default:
                next_state = IDLE;
        endcase
    end

    
    always @(*) begin
        prompt_pin   = 1'b0;
        show_menu    = 1'b0;
        dispensing   = 1'b0;
        show_balance = 1'b0;
        ejecting     = 1'b0;

        case (state)
            WAIT_PIN: prompt_pin   = 1'b1;
            OPTIONS:  show_menu    = 1'b1;
            DISPENSE: dispensing   = 1'b1;
            BALANCE:  show_balance = 1'b1;
            EJECT:    ejecting     = 1'b1;
            default: ;
        endcase
    end

endmodule