
module risc_5stage (
    input clk,
    input reset
);

    // Instruction and Data Memories
    reg [31:0] imem [0:255];
    reg [31:0] dmem [0:255];

    // Register File
    reg [31:0] regfile [0:31];

    // Program Counter
    reg [31:0] PC;

    // -------------------------
    // IF/ID Pipeline Registers
    // -------------------------
    reg [31:0] IF_ID_instr;
    reg [31:0] IF_ID_pc;

    // -------------------------
    // ID/EX Pipeline Registers
    // -------------------------
    reg [31:0] ID_EX_pc;
    reg [31:0] ID_EX_rd1;
    reg [31:0] ID_EX_rd2;
    reg [31:0] ID_EX_imm;

    reg [4:0] ID_EX_rs;
    reg [4:0] ID_EX_rt;
    reg [4:0] ID_EX_rd;

    reg [5:0] ID_EX_funct;
    reg [5:0] ID_EX_opcode;

    reg ID_EX_RegWrite;
    reg ID_EX_MemRead;
    reg ID_EX_MemWrite;
    reg ID_EX_MemtoReg;
    reg ID_EX_ALUSrc;
    reg [1:0] ID_EX_ALUOp;

    // -------------------------
    // EX/MEM Pipeline Registers
    // -------------------------
    reg [31:0] EX_MEM_alu_result;
    reg [31:0] EX_MEM_write_data;
    reg [4:0] EX_MEM_rd;

    reg EX_MEM_RegWrite;
    reg EX_MEM_MemRead;
    reg EX_MEM_MemWrite;
    reg EX_MEM_MemtoReg;

    // -------------------------
    // MEM/WB Pipeline Registers
    // -------------------------
    reg [31:0] MEM_WB_mem_data;
    reg [31:0] MEM_WB_alu_result;
    reg [4:0] MEM_WB_rd;

    reg MEM_WB_RegWrite;
    reg MEM_WB_MemtoReg;

    // Control Signals
    reg RegWrite, MemRead, MemWrite;
    reg MemtoReg, ALUSrc;
    reg [1:0] ALUOp;

    // ALU
    reg [31:0] alu_result;
    reg [31:0] alu_input2;

    integer i;

    // -------------------------
    // Instruction Memory Initialization
    // -------------------------
    initial begin

        $readmemh("program.hex", imem);

        for (i = 0; i < 32; i = i + 1)
            regfile[i] = 0;

        for (i = 0; i < 256; i = i + 1)
            dmem[i] = 0;

    end

    // -------------------------
    // Instruction Decode Stage
    // -------------------------
    always @(*) begin

        RegWrite = 0;
        MemRead  = 0;
        MemWrite = 0;
        MemtoReg = 0;
        ALUSrc   = 0;
        ALUOp    = 2'b00;

        case (IF_ID_instr[31:26])

            // R-Type Instruction
            6'b000000: begin
                RegWrite = 1;
                ALUOp = 2'b10;
            end

            // Load Word
            6'b100011: begin
                RegWrite = 1;
                MemRead = 1;
                MemtoReg = 1;
                ALUSrc = 1;
            end

            // Store Word
            6'b101011: begin
                MemWrite = 1;
                ALUSrc = 1;
            end

            // Add Immediate
            6'b001000: begin
                RegWrite = 1;
                ALUSrc = 1;
                ALUOp = 2'b00;
            end

            default: begin
            end

        endcase

    end

    // -------------------------
    // Execute Stage - ALU
    // -------------------------
    always @(*) begin

        if (ID_EX_ALUSrc)
            alu_input2 = ID_EX_imm;
        else
            alu_input2 = ID_EX_rd2;

        case (ID_EX_ALUOp)

            // ADD / LW / SW / ADDI
            2'b00:
                alu_result = ID_EX_rd1 + alu_input2;

            // R-Type Instructions
            2'b10: begin

                case (ID_EX_funct)

                    // ADD
                    6'b100000:
                        alu_result = ID_EX_rd1 + alu_input2;

                    // SUB
                    6'b100010:
                        alu_result = ID_EX_rd1 - alu_input2;

                    // AND
                    6'b100100:
                        alu_result = ID_EX_rd1 & alu_input2;

                    // OR
                    6'b100101:
                        alu_result = ID_EX_rd1 | alu_input2;

                    default:
                        alu_result = 0;

                endcase

            end

            default:
                alu_result = 0;

        endcase

    end

    // -------------------------
    // Pipeline Operation
    // -------------------------
    always @(posedge clk or posedge reset) begin

        if (reset) begin

            PC <= 0;

            IF_ID_instr <= 0;
            IF_ID_pc <= 0;

            ID_EX_pc <= 0;
            ID_EX_rd1 <= 0;
            ID_EX_rd2 <= 0;
            ID_EX_imm <= 0;
            ID_EX_rs <= 0;
            ID_EX_rt <= 0;
            ID_EX_rd <= 0;
            ID_EX_funct <= 0;
            ID_EX_opcode <= 0;

            ID_EX_RegWrite <= 0;
            ID_EX_MemRead <= 0;
            ID_EX_MemWrite <= 0;
            ID_EX_MemtoReg <= 0;
            ID_EX_ALUSrc <= 0;
            ID_EX_ALUOp <= 0;

            EX_MEM_alu_result <= 0;
            EX_MEM_write_data <= 0;
            EX_MEM_rd <= 0;

            EX_MEM_RegWrite <= 0;
            EX_MEM_MemRead <= 0;
            EX_MEM_MemWrite <= 0;
            EX_MEM_MemtoReg <= 0;

            MEM_WB_mem_data <= 0;
            MEM_WB_alu_result <= 0;
            MEM_WB_rd <= 0;

            MEM_WB_RegWrite <= 0;
            MEM_WB_MemtoReg <= 0;

        end

        else begin

            // -------------------------
            // WB Stage
            // -------------------------
            if (MEM_WB_RegWrite && MEM_WB_rd != 0) begin

                if (MEM_WB_MemtoReg)
                    regfile[MEM_WB_rd] <= MEM_WB_mem_data;

                else
                    regfile[MEM_WB_rd] <= MEM_WB_alu_result;

            end

            // -------------------------
            // IF Stage
            // -------------------------
            IF_ID_instr <= imem[PC[9:2]];
            IF_ID_pc <= PC;
            PC <= PC + 4;

            // -------------------------
            // ID Stage
            // -------------------------
            ID_EX_pc <= IF_ID_pc;

            ID_EX_rs <= IF_ID_instr[25:21];
            ID_EX_rt <= IF_ID_instr[20:16];
            ID_EX_rd <= IF_ID_instr[15:11];

            ID_EX_rd1 <= regfile[IF_ID_instr[25:21]];
            ID_EX_rd2 <= regfile[IF_ID_instr[20:16]];

            ID_EX_imm <=
                {{16{IF_ID_instr[15]}},
                 IF_ID_instr[15:0]};

            ID_EX_funct <= IF_ID_instr[5:0];
            ID_EX_opcode <= IF_ID_instr[31:26];

            ID_EX_RegWrite <= RegWrite;
            ID_EX_MemRead <= MemRead;
            ID_EX_MemWrite <= MemWrite;
            ID_EX_MemtoReg <= MemtoReg;
            ID_EX_ALUSrc <= ALUSrc;
            ID_EX_ALUOp <= ALUOp;

            // -------------------------
            // EX Stage
            // -------------------------
            EX_MEM_alu_result <= alu_result;
            EX_MEM_write_data <= ID_EX_rd2;

            if (ID_EX_opcode == 6'b000000)
                EX_MEM_rd <= ID_EX_rd;

            else
                EX_MEM_rd <= ID_EX_rt;

            EX_MEM_RegWrite <= ID_EX_RegWrite;
            EX_MEM_MemRead <= ID_EX_MemRead;
            EX_MEM_MemWrite <= ID_EX_MemWrite;
            EX_MEM_MemtoReg <= ID_EX_MemtoReg;

            // -------------------------
            // MEM Stage
            // -------------------------
            if (EX_MEM_MemWrite)
                dmem[EX_MEM_alu_result[9:2]]
                    <= EX_MEM_write_data;

            if (EX_MEM_MemRead)
                MEM_WB_mem_data
                    <= dmem[EX_MEM_alu_result[9:2]];

            else
                MEM_WB_mem_data <= 0;

            MEM_WB_alu_result <= EX_MEM_alu_result;
            MEM_WB_rd <= EX_MEM_rd;

            MEM_WB_RegWrite <= EX_MEM_RegWrite;
            MEM_WB_MemtoReg <= EX_MEM_MemtoReg;

        end

    end

endmodule
