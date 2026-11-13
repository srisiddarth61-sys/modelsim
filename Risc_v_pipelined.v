`timescale 1ns/1ps

(* dont_touch = "true" *) 
module Risc_v_pipelined (
    input wire clk,
    input wire reset,
    output wire [31:0] probe_pc 
);

    // Memory & Registers
    reg [31:0] pc;
    assign probe_pc = pc;

    reg [31:0] instruction_mem [0:63];
    reg [31:0] data_mem        [0:63];
    reg [31:0] registers       [0:31];

    // IF/ID Pipeline Register
    reg [31:0] if_id_pc, if_id_inst;

    // ID/EX Pipeline Register
    reg [31:0] id_ex_pc, id_ex_r1, id_ex_r2, id_ex_imm;
    reg [4:0]  id_ex_rs1, id_ex_rs2, id_ex_rd;
    reg [3:0]  id_ex_alu_ctrl; 
    reg [2:0]  id_ex_branch_type;
    reg        id_ex_alu_src, id_ex_mem_write, id_ex_mem_read;
    reg        id_ex_branch, id_ex_jump, id_ex_reg_write, id_ex_mem_to_reg;

    // EX/MEM Pipeline Register
    reg [31:0] ex_mem_alu_res, ex_mem_r2;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_mem_write, ex_mem_mem_read, ex_mem_reg_write, ex_mem_mem_to_reg;

    // MEM/WB Pipeline Register
    reg [31:0] mem_wb_alu_res, mem_wb_mem_data;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write, mem_wb_mem_to_reg;

    // Global wire for Writeback data
    wire [31:0] wb_write_data = mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_alu_res;

    // =========================================================================
    // INSTRUCTION DECODE STAGE & INTERNAL BYPASS
    // =========================================================================
    wire [6:0] opcode = if_id_inst[6:0];
    wire [4:0] rd     = if_id_inst[11:7];
    wire [2:0] funct3 = if_id_inst[14:12];
    wire [4:0] rs1    = if_id_inst[19:15];
    wire [4:0] rs2    = if_id_inst[24:20];
    wire [6:0] funct7 = if_id_inst[31:25];

    wire [31:0] rdata1 = (rs1 == 0) ? 32'd0 : 
                         (mem_wb_reg_write && (mem_wb_rd == rs1)) ? wb_write_data : registers[rs1];
                         
    wire [31:0] rdata2 = (rs2 == 0) ? 32'd0 : 
                         (mem_wb_reg_write && (mem_wb_rd == rs2)) ? wb_write_data : registers[rs2];

    wire [31:0] imm_i = {{20{if_id_inst[31]}}, if_id_inst[31:20]};
    wire [31:0] imm_s = {{20{if_id_inst[31]}}, if_id_inst[31:25], if_id_inst[11:7]};
    wire [31:0] imm_b = {{19{if_id_inst[31]}}, if_id_inst[31], if_id_inst[7], if_id_inst[30:25], if_id_inst[11:8], 1'b0};
    wire [31:0] imm_u = {if_id_inst[31:12], 12'd0};
    wire [31:0] imm_j = {{12{if_id_inst[31]}}, if_id_inst[19:12], if_id_inst[20], if_id_inst[30:21], 1'b0};

    reg [31:0] imm;
    reg        c_alu_src, c_mem_write, c_mem_read, c_branch, c_jump, c_reg_write, c_mem_to_reg;
    reg [3:0]  c_alu_ctrl;
    reg [2:0]  c_branch_type;

    always @(*) begin
        c_alu_src = 0; c_mem_write = 0; c_mem_read = 0; c_branch = 0; c_jump = 0;
        c_reg_write = 0; c_mem_to_reg = 0; c_alu_ctrl = 4'b0000; c_branch_type = 3'b000;
        imm = 32'd0;

        case (opcode)
            7'b0110011: begin // R-type
                c_reg_write = 1;
                if (funct3 == 3'b000 && funct7 == 7'b0100000) c_alu_ctrl = 4'b0001; // SUB
                else if (funct3 == 3'b000) c_alu_ctrl = 4'b0000; // ADD
                else if (funct3 == 3'b111) c_alu_ctrl = 4'b0010; // AND
                else if (funct3 == 3'b110) c_alu_ctrl = 4'b0011; // OR
                else if (funct3 == 3'b100) c_alu_ctrl = 4'b0100; // XOR
                else if (funct3 == 3'b010) c_alu_ctrl = 4'b0101; // SLT
                else if (funct3 == 3'b001) c_alu_ctrl = 4'b0110; // SLL
                else if (funct3 == 3'b101) c_alu_ctrl = 4'b0111; // SRL
            end
            7'b0010011: begin // I-type ALU
                c_reg_write = 1; c_alu_src = 1; imm = imm_i;
                if (funct3 == 3'b000) c_alu_ctrl = 4'b0000;      // ADDI
                else if (funct3 == 3'b111) c_alu_ctrl = 4'b0010; // ANDI
                else if (funct3 == 3'b110) c_alu_ctrl = 4'b0011; // ORI
                else if (funct3 == 3'b100) c_alu_ctrl = 4'b0100; // XORI
                else if (funct3 == 3'b010) c_alu_ctrl = 4'b0101; // SLTI
                else if (funct3 == 3'b001) c_alu_ctrl = 4'b0110; // SLLI
                else if (funct3 == 3'b101) c_alu_ctrl = 4'b0111; // SRLI
            end
            7'b0000011: begin // LW
                c_reg_write = 1; c_alu_src = 1; c_mem_read = 1; c_mem_to_reg = 1; imm = imm_i;
            end
            7'b0100011: begin // SW
                c_mem_write = 1; c_alu_src = 1; imm = imm_s;
            end
            7'b1100011: begin // Branch (BEQ, BNE, BLT, BGE)
                c_branch = 1; imm = imm_b; c_branch_type = funct3; 
            end
            7'b0110111: begin // LUI
                c_reg_write = 1; c_alu_src = 1; imm = imm_u; c_alu_ctrl = 4'b1000; // PASS_B
            end
            7'b1101111: begin // JAL
                c_reg_write = 1; c_jump = 1; imm = imm_j; 
            end
            7'b1100111: begin // JALR
                c_reg_write = 1; c_jump = 1; c_alu_src = 1; imm = imm_i; c_branch_type = 3'b111; // JALR tag
            end
            default: ; 
        endcase
    end

    wire load_use_hazard = id_ex_mem_read && (id_ex_rd != 0) && ((id_ex_rd == rs1) || (id_ex_rd == rs2));

    // =========================================================================
    // EXECUTE STAGE & FORWARDING UNIT
    // =========================================================================
    wire [1:0] forward_a = (ex_mem_reg_write && ex_mem_rd != 0 && ex_mem_rd == id_ex_rs1) ? 2'b10 :
                           (mem_wb_reg_write && mem_wb_rd != 0 && mem_wb_rd == id_ex_rs1) ? 2'b01 : 2'b00;

    wire [1:0] forward_b = (ex_mem_reg_write && ex_mem_rd != 0 && ex_mem_rd == id_ex_rs2) ? 2'b10 :
                           (mem_wb_reg_write && mem_wb_rd != 0 && mem_wb_rd == id_ex_rs2) ? 2'b01 : 2'b00;

    wire [31:0] alu_in1 = (forward_a == 2'b10) ? ex_mem_alu_res : (forward_a == 2'b01) ? wb_write_data : id_ex_r1;
    wire [31:0] fwd_in2 = (forward_b == 2'b10) ? ex_mem_alu_res : (forward_b == 2'b01) ? wb_write_data : id_ex_r2;
    wire [31:0] alu_in2 = id_ex_alu_src ? id_ex_imm : fwd_in2;

    reg [31:0] alu_result;
    always @(*) begin
        if (id_ex_jump) begin
            alu_result = id_ex_pc + 4; // JAL/JALR links PC+4 to register
        end else begin
            case (id_ex_alu_ctrl)
                4'b0000: alu_result = alu_in1 + alu_in2; // ADD
                4'b0001: alu_result = alu_in1 - alu_in2; // SUB
                4'b0010: alu_result = alu_in1 & alu_in2; // AND
                4'b0011: alu_result = alu_in1 | alu_in2; // OR
                4'b0100: alu_result = alu_in1 ^ alu_in2; // XOR
                4'b0101: alu_result = ($signed(alu_in1) < $signed(alu_in2)) ? 1 : 0; // SLT
                4'b0110: alu_result = alu_in1 << alu_in2[4:0]; // SLL
                4'b0111: alu_result = alu_in1 >> alu_in2[4:0]; // SRL
                4'b1000: alu_result = alu_in2;           // PASS_B (LUI)
                default: alu_result = 32'd0;
            endcase
        end
    end

    reg branch_condition;
    always @(*) begin
        case (id_ex_branch_type)
            3'b000: branch_condition = (alu_in1 == fwd_in2); // BEQ
            3'b001: branch_condition = (alu_in1 != fwd_in2); // BNE
            3'b100: branch_condition = ($signed(alu_in1) < $signed(fwd_in2)); // BLT
            3'b101: branch_condition = ($signed(alu_in1) >= $signed(fwd_in2)); // BGE
            default: branch_condition = 0;
        endcase
    end

    wire branch_taken = (id_ex_branch && branch_condition) || id_ex_jump;
    wire [31:0] branch_target = (id_ex_jump && id_ex_branch_type == 3'b111) ? 
                                (alu_in1 + id_ex_imm) : (id_ex_pc + id_ex_imm); // JALR vs Branch/JAL

    // =========================================================================
    // PIPELINE REGISTERS
    // =========================================================================
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 0;
            if_id_inst <= 32'h00000013; if_id_pc <= 0;
            id_ex_alu_ctrl <= 0; id_ex_reg_write <= 0; id_ex_mem_write <= 0; id_ex_branch <= 0; 
            id_ex_mem_read <= 0; id_ex_rd <= 0; id_ex_jump <= 0;
            ex_mem_reg_write <= 0; ex_mem_mem_write <= 0; ex_mem_rd <= 0; ex_mem_mem_read <= 0;
            mem_wb_reg_write <= 0; mem_wb_rd <= 0;
            for (i = 0; i < 32; i = i + 1) registers[i] <= 32'd0;
        end else begin
            
            // --- STAGE 5: WRITE BACK (WB) ---
            if (mem_wb_reg_write && mem_wb_rd != 0) 
                registers[mem_wb_rd] <= wb_write_data;
            registers[0] <= 32'd0; 

            // --- STAGE 4: MEMORY (MEM) ---
            mem_wb_alu_res    <= ex_mem_alu_res;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_reg_write  <= ex_mem_reg_write;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
            
            if (ex_mem_mem_read) mem_wb_mem_data <= data_mem[ex_mem_alu_res[7:2]];
            else mem_wb_mem_data <= 32'd0;

            if (ex_mem_mem_write) data_mem[ex_mem_alu_res[7:2]] <= ex_mem_r2;

            // --- STAGE 3: EXECUTE (EX) ---
            ex_mem_alu_res    <= alu_result;
            ex_mem_r2         <= fwd_in2;
            ex_mem_rd         <= id_ex_rd;
            ex_mem_mem_write  <= id_ex_mem_write;
            ex_mem_mem_read   <= id_ex_mem_read;
            ex_mem_reg_write  <= id_ex_reg_write;
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;

            // --- STAGE 2: INSTRUCTION DECODE (ID) ---
            if (branch_taken || load_use_hazard) begin
                // Inject NOP (Stall or Flush)
                id_ex_reg_write <= 0; id_ex_mem_write <= 0; id_ex_branch <= 0; 
                id_ex_mem_read <= 0; id_ex_jump <= 0;
            end else begin
                id_ex_pc         <= if_id_pc;
                id_ex_r1         <= rdata1;
                id_ex_r2         <= rdata2;
                id_ex_imm        <= imm;
                id_ex_rs1        <= rs1;
                id_ex_rs2        <= rs2;
                id_ex_rd         <= rd;
                id_ex_alu_ctrl   <= c_alu_ctrl;
                id_ex_alu_src    <= c_alu_src;
                id_ex_mem_write  <= c_mem_write;
                id_ex_mem_read   <= c_mem_read;
                id_ex_branch     <= c_branch;
                id_ex_jump       <= c_jump;
                id_ex_branch_type<= c_branch_type;
                id_ex_reg_write  <= c_reg_write;
                id_ex_mem_to_reg <= c_mem_to_reg;
            end

            // --- STAGE 1: INSTRUCTION FETCH (IF) ---
            if (branch_taken) begin
                pc <= branch_target;
                if_id_inst <= 32'h00000013; // Flush with NOP
                if_id_pc   <= branch_target;
            end else if (!load_use_hazard) begin
                if_id_inst <= instruction_mem[pc[7:2]];
                if_id_pc   <= pc;
                pc         <= pc + 32'd4;
            end

        end
    end
endmodule