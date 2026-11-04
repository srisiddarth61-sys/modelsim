`timescale 1ns/1ps

module atm_controller_tb;

    reg clk;
    reg reset;
    reg card_inserted;
    reg pin_valid;
    reg pin_invalid;
    reg req_withdraw;
    reg req_balance;
    reg cancel;
    reg dispense_done;

    wire prompt_pin;
    wire show_menu;
    wire dispensing;
    wire show_balance;
    wire ejecting;

    // Device under test
    atm_controller uut (
        .clk(clk),
        .reset(reset),
        .card_inserted(card_inserted),
        .pin_valid(pin_valid),
        .pin_invalid(pin_invalid),
        .req_withdraw(req_withdraw),
        .req_balance(req_balance),
        .cancel(cancel),
        .dispense_done(dispense_done),
        .prompt_pin(prompt_pin),
        .show_menu(show_menu),
        .dispensing(dispensing),
        .show_balance(show_balance),
        .ejecting(ejecting)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    initial begin
        // Initialize inputs
        clk = 1'b0;
        reset = 1'b1;
        card_inserted = 1'b0;
        pin_valid = 1'b0;
        pin_invalid = 1'b0;
        req_withdraw = 1'b0;
        req_balance = 1'b0;
        cancel = 1'b0;
        dispense_done = 1'b0;

        // Reset
        #12;
        reset = 1'b0;

        // Insert card
        @(negedge clk);
        card_inserted = 1'b1;

        // Simulate User PIN Entry
        repeat (2) @(negedge clk);
        pin_valid = 1'b1;
        @(negedge clk);
        pin_valid = 1'b0;

        // Check Balance First
        repeat (2) @(negedge clk);
        req_balance = 1'b1;
        @(negedge clk);
        req_balance = 1'b0;

        // Cancel to return to options menu
        repeat (2) @(negedge clk);
        cancel = 1'b1;
        @(negedge clk);
        cancel = 1'b0;

        // Request Withdrawal
        repeat (2) @(negedge clk);
        req_withdraw = 1'b1;
        @(negedge clk);
        req_withdraw = 1'b0;

        // Dispense Done
        repeat (2) @(negedge clk);
        dispense_done = 1'b1;
        @(negedge clk);
        dispense_done = 1'b0;
        
        // Remove card after EJECT state is hit
        repeat (2) @(negedge clk);
        card_inserted = 1'b0;

        // Check completion
        @(negedge clk);
        if (uut.state === 3'b000) // Back to IDLE
            $display("TEST PASSED: ATM transaction completed and returned to IDLE!");
        else
            $display("TEST FAILED: Machine did not return to IDLE.");

        #10;
        $finish;
    end

    // Display state and outputs
    initial begin
        $monitor(
            "Time=%0t | State=%b | PromptPIN=%b | Menu=%b | Dispense=%b | Balance=%b | Eject=%b",
            $time, uut.state, prompt_pin, show_menu,
            dispensing, show_balance, ejecting
        );
    end

endmodule