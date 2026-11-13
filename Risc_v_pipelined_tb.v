`timescale 1ns/1ps

module Risc_v_pipelined_tb;
    reg clk;
    reg reset;
    wire [31:0] probe_pc;

    // Performance Counters (Day 4 Requirement)
    integer total_cycles = 0;
    integer instructions_retired = 0;
    integer i;

    // Updated instance name
    Risc_v_pipelined dut (
        .clk(clk),
        .reset(reset),
        .probe_pc(probe_pc)
    );

    always #5 clk = ~clk;

    // Count cycles and retired instructions (when mem_wb_rd != 0 or mem/branch executes)
    always @(posedge clk) begin
        if (!reset) begin
            total_cycles = total_cycles + 1;
            // Simplistic retirement counter: count when WB stage has valid write or MEM has valid write
            if (dut.mem_wb_reg_write || dut.ex_mem_mem_write || dut.id_ex_branch || dut.id_ex_jump) begin
                instructions_retired = instructions_retired + 1;
            end
        end
    end

    initial begin
        clk = 0;
        reset = 1;

        // Clear memory
        for (i = 0; i < 64; i = i + 1) begin
            dut.instruction_mem[i] = 32'h00000013; 
            dut.data_mem[i] = 0;
        end

        // Load the external Hex file containing the Day 3 Assembly Program
        // Make sure to create a "program1.hex" file in your simulation directory
        $readmemh("program1.hex", dut.instruction_mem);

        #12;
        reset = 0;

        // Let the program run (adjust this wait time based on your program's loop count)
        repeat (100) @(posedge clk);
        
        $display("--------------------------------------");
        $display("   Pipeline Execution Complete");
        $display("--------------------------------------");
        $display("Total Clock Cycles: %0d", total_cycles);
        $display("Instructions Executed (approx): %0d", instructions_retired);
        if (instructions_retired > 0)
            $display("Average CPI: %0f", $itor(total_cycles) / instructions_retired);
        $display("--------------------------------------");

        $finish;
    end
endmodule