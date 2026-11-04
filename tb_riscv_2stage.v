
`timescale 1ns/1ps

module risc_5stage_tb;

    // -------------------------
    // Input Signals
    // -------------------------
    reg clk;
    reg reset;

    // -------------------------
    // Instantiate RISC Processor
    // -------------------------
    risc_5stage uut (
        .clk(clk),
        .reset(reset)
    );

    // -------------------------
    // Clock Generation
    // -------------------------
    always #5 clk = ~clk;

    // -------------------------
    // Testbench Operation
    // -------------------------
    initial begin

        // Initialize Signals
        clk = 0;
        reset = 1;

        // Display Header
        $display("--------------------------------");
        $display("   32-BIT RISC PROCESSOR");
        $display("   5-STAGE PIPELINE");
        $display("--------------------------------");

        // Apply Reset
        #10;
        reset = 0;

        // Start Processor
        $display("Reset Released");
        $display("Processor Started");

        // Wait for Execution
        #200;

        // -------------------------
        // Display Register Values
        // -------------------------
        $display("--------------------------------");
        $display("       FINAL OUTPUT");
        $display("--------------------------------");

        $display("R1 = %d", uut.regfile[1]);
        $display("R2 = %d", uut.regfile[2]);
        $display("R3 = %d", uut.regfile[3]);

        // -------------------------
        // Verify Expected Results
        // -------------------------
        if (uut.regfile[1] == 5 &&
            uut.regfile[2] == 10 &&
            uut.regfile[3] == 15)
        begin
            $display("TEST PASSED");
        end

        else begin
            $display("TEST FAILED");
        end

        // -------------------------
        // End Simulation
        // -------------------------
        $display("--------------------------------");

        $finish;

    end

endmodule
