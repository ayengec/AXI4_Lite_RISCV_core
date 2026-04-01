//==============================================================
// File: rv32i_decoder.sv
// Description: RV32I instruction decoder
//
// Requirements covered:
//   - ID-001 : support R/I/S/B/U/J formats
//   - ID-002 : opcode decode
//   - ID-003 : source register decode
//   - ID-004 : destination register decode
//   - ID-005 : funct3 decode
//   - ID-006 : funct7 decode
//   - ID-007 : I-type immediate generation
//   - ID-008 : S-type immediate generation
//   - ID-009 : B-type immediate generation
//   - ID-010 : U-type immediate generation
//   - ID-011 : J-type immediate generation
//   - ID-012 : illegal instruction detection
//
// Also generates control signals used by:
//   - ALU requirements
//   - Branch/jump requirements
//   - Memory access requirements
//==============================================================

import rv32i_pkg::*;

module rv32i_decoder (
  input  logic [31:0] instr_i,

  // Decoded instruction fields
  output logic [6:0]  opcode_o,
  output logic [4:0]  rs1_o,
  output logic [4:0]  rs2_o,
  output logic [4:0]  rd_o,
  output logic [2:0]  funct3_o,
  output logic [6:0]  funct7_o,

  // Immediates
  output logic [31:0] imm_i_type_o,
  output logic [31:0] imm_s_type_o,
  output logic [31:0] imm_b_type_o,
  output logic [31:0] imm_u_type_o,
  output logic [31:0] imm_j_type_o,

  // Main control
  output logic        use_rs1_o,
  output logic        use_rs2_o,
  output logic        reg_write_o,
  output logic        alu_src_imm_o,
  output alu_op_e     alu_op_o,
  output wb_sel_e     wb_sel_o,

  // Branch/jump control
  output logic        is_branch_o,
  output logic        is_jal_o,
  output logic        is_jalr_o,
  output branch_op_e  branch_op_o,

  // Memory control
  output logic        is_load_o,
  output logic        is_store_o,
  output mem_size_e   mem_size_o,
  output logic        load_unsigned_o,

  // Special ALU source cases
  output logic        op_a_is_pc_o,
  output logic        op_b_is_uimm_o,

  // Illegal instruction
  output logic        illegal_instr_o
);

  logic [11:0] imm12;
  logic [4:0]  shamt;

  // -----------------------------------------------------------
  // ID-002/003/004/005/006: field extraction
  // -----------------------------------------------------------
  assign opcode_o = instr_i[6:0];
  assign rd_o     = instr_i[11:7];
  assign funct3_o = instr_i[14:12];
  assign rs1_o    = instr_i[19:15];
  assign rs2_o    = instr_i[24:20];
  assign funct7_o = instr_i[31:25];

  assign imm12    = instr_i[31:20];
  assign shamt    = instr_i[24:20];

  // -----------------------------------------------------------
  // ID-007: I-type immediate
  // -----------------------------------------------------------
  assign imm_i_type_o = {{20{instr_i[31]}}, instr_i[31:20]};

  // -----------------------------------------------------------
  // ID-008: S-type immediate
  // -----------------------------------------------------------
  assign imm_s_type_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};

  // -----------------------------------------------------------
  // ID-009: B-type immediate
  // bit[0] is implicit zero
  // -----------------------------------------------------------
  assign imm_b_type_o = {
    {19{instr_i[31]}},
    instr_i[31],
    instr_i[7],
    instr_i[30:25],
    instr_i[11:8],
    1'b0
  };

  // -----------------------------------------------------------
  // ID-010: U-type immediate
  // -----------------------------------------------------------
  assign imm_u_type_o = {instr_i[31:12], 12'b0};

  // -----------------------------------------------------------
  // ID-011: J-type immediate
  // bit[0] is implicit zero
  // -----------------------------------------------------------
  assign imm_j_type_o = {
    {11{instr_i[31]}},
    instr_i[31],
    instr_i[19:12],
    instr_i[20],
    instr_i[30:21],
    1'b0
  };

  // -----------------------------------------------------------
  // Main decode / control generation
  // -----------------------------------------------------------
  always_comb begin
    // Safe defaults
    use_rs1_o        = 1'b0;
    use_rs2_o        = 1'b0;
    reg_write_o      = 1'b0;
    alu_src_imm_o    = 1'b0;
    alu_op_o         = ALU_ADD;
    wb_sel_o         = WB_NONE;

    is_branch_o      = 1'b0;
    is_jal_o         = 1'b0;
    is_jalr_o        = 1'b0;
    branch_op_o      = BR_NONE;

    is_load_o        = 1'b0;
    is_store_o       = 1'b0;
    mem_size_o       = MEM_NONE;
    load_unsigned_o  = 1'b0;

    op_a_is_pc_o     = 1'b0;
    op_b_is_uimm_o   = 1'b0;

    illegal_instr_o  = 1'b0;

    unique case (opcode_o)

      // -------------------------------------------------------
      // LUI
      // ALU-014
      // -------------------------------------------------------
      OPCODE_LUI: begin
        reg_write_o    = 1'b1;
        wb_sel_o       = WB_ALU;
        alu_op_o       = ALU_COPY_B;
        op_b_is_uimm_o = 1'b1;
      end

      // -------------------------------------------------------
      // AUIPC
      // ALU-015
      // -------------------------------------------------------
      OPCODE_AUIPC: begin
        reg_write_o    = 1'b1;
        wb_sel_o       = WB_ALU;
        alu_op_o       = ALU_ADD;
        op_a_is_pc_o   = 1'b1;
        op_b_is_uimm_o = 1'b1;
      end

      // -------------------------------------------------------
      // JAL
      // JMP-001
      // -------------------------------------------------------
      OPCODE_JAL: begin
        reg_write_o    = 1'b1;
        wb_sel_o       = WB_PC4;
        is_jal_o       = 1'b1;
      end

      // -------------------------------------------------------
      // JALR
      // JMP-002
      // -------------------------------------------------------
      OPCODE_JALR: begin
        use_rs1_o      = 1'b1;
        reg_write_o    = 1'b1;
        wb_sel_o       = WB_PC4;
        is_jalr_o      = 1'b1;

        // RV32I JALR requires funct3 == 000
        if (funct3_o != 3'b000) begin
          illegal_instr_o = 1'b1;
          reg_write_o     = 1'b0;
          wb_sel_o        = WB_NONE;
          is_jalr_o       = 1'b0;
        end
      end

      // -------------------------------------------------------
      // Conditional branches
      // BRN-001..006
      // -------------------------------------------------------
      OPCODE_BRANCH: begin
        use_rs1_o    = 1'b1;
        use_rs2_o    = 1'b1;
        is_branch_o  = 1'b1;

        unique case (funct3_o)
          3'b000: branch_op_o = BR_BEQ;
          3'b001: branch_op_o = BR_BNE;
          3'b100: branch_op_o = BR_BLT;
          3'b101: branch_op_o = BR_BGE;
          3'b110: branch_op_o = BR_BLTU;
          3'b111: branch_op_o = BR_BGEU;
          default: begin
            illegal_instr_o = 1'b1;
            is_branch_o     = 1'b0;
            branch_op_o     = BR_NONE;
          end
        endcase
      end

      // -------------------------------------------------------
      // Loads
      // MEM-001..005
      // -------------------------------------------------------
      OPCODE_LOAD: begin
        use_rs1_o      = 1'b1;
        reg_write_o    = 1'b1;
        alu_src_imm_o  = 1'b1;
        alu_op_o       = ALU_ADD;
        wb_sel_o       = WB_MEM;
        is_load_o      = 1'b1;

        unique case (funct3_o)
          3'b000: begin // LB
            mem_size_o      = MEM_BYTE;
            load_unsigned_o = 1'b0;
          end
          3'b001: begin // LH
            mem_size_o      = MEM_HALF;
            load_unsigned_o = 1'b0;
          end
          3'b010: begin // LW
            mem_size_o      = MEM_WORD;
            load_unsigned_o = 1'b0;
          end
          3'b100: begin // LBU
            mem_size_o      = MEM_BYTE;
            load_unsigned_o = 1'b1;
          end
          3'b101: begin // LHU
            mem_size_o      = MEM_HALF;
            load_unsigned_o = 1'b1;
          end
          default: begin
            illegal_instr_o = 1'b1;
            reg_write_o     = 1'b0;
            wb_sel_o        = WB_NONE;
            is_load_o       = 1'b0;
            mem_size_o      = MEM_NONE;
          end
        endcase
      end

      // -------------------------------------------------------
      // Stores
      // MEM-006..008
      // -------------------------------------------------------
      OPCODE_STORE: begin
        use_rs1_o      = 1'b1;
        use_rs2_o      = 1'b1;
        alu_src_imm_o  = 1'b1;
        alu_op_o       = ALU_ADD;
        is_store_o     = 1'b1;

        unique case (funct3_o)
          3'b000: mem_size_o = MEM_BYTE; // SB
          3'b001: mem_size_o = MEM_HALF; // SH
          3'b010: mem_size_o = MEM_WORD; // SW
          default: begin
            illegal_instr_o = 1'b1;
            is_store_o      = 1'b0;
            mem_size_o      = MEM_NONE;
          end
        endcase
      end

      // -------------------------------------------------------
      // OP-IMM
      // ALU-003,004,005,006,007,008,009,012,013
      // -------------------------------------------------------
      OPCODE_OP_IMM: begin
        use_rs1_o      = 1'b1;
        reg_write_o    = 1'b1;
        alu_src_imm_o  = 1'b1;
        wb_sel_o       = WB_ALU;

        unique case (funct3_o)
          3'b000: alu_op_o = ALU_ADD;  // ADDI
          3'b010: alu_op_o = ALU_SLT;  // SLTI
          3'b011: alu_op_o = ALU_SLTU; // SLTIU
          3'b100: alu_op_o = ALU_XOR;  // XORI
          3'b110: alu_op_o = ALU_OR;   // ORI
          3'b111: alu_op_o = ALU_AND;  // ANDI

          3'b001: begin // SLLI
            alu_op_o = ALU_SLL;
            // RV32I requires funct7 == 0000000 for SLLI
            if (funct7_o != 7'b0000000) begin
              illegal_instr_o = 1'b1;
              reg_write_o     = 1'b0;
              wb_sel_o        = WB_NONE;
            end
          end

          3'b101: begin
            // SRLI / SRAI
            unique case (funct7_o)
              7'b0000000: alu_op_o = ALU_SRL;
              7'b0100000: alu_op_o = ALU_SRA;
              default: begin
                illegal_instr_o = 1'b1;
                reg_write_o     = 1'b0;
                wb_sel_o        = WB_NONE;
              end
            endcase
          end

          default: begin
            illegal_instr_o = 1'b1;
            reg_write_o     = 1'b0;
            wb_sel_o        = WB_NONE;
          end
        endcase
      end

      // -------------------------------------------------------
      // OP
      // ALU-001,002,004,005,006,007,008,009,010,011
      // -------------------------------------------------------
      OPCODE_OP: begin
        use_rs1_o      = 1'b1;
        use_rs2_o      = 1'b1;
        reg_write_o    = 1'b1;
        wb_sel_o       = WB_ALU;

        unique case (funct3_o)
          3'b000: begin
            unique case (funct7_o)
              7'b0000000: alu_op_o = ALU_ADD; // ADD
              7'b0100000: alu_op_o = ALU_SUB; // SUB
              default: begin
                illegal_instr_o = 1'b1;
                reg_write_o     = 1'b0;
                wb_sel_o        = WB_NONE;
              end
            endcase
          end

          3'b001: begin
            if (funct7_o == 7'b0000000) begin
              alu_op_o = ALU_SLL;
            end
            else begin
              illegal_instr_o = 1'b1;
              reg_write_o     = 1'b0;
              wb_sel_o        = WB_NONE;
            end
          end

          3'b010: begin
            if (funct7_o == 7'b0000000) begin
              alu_op_o = ALU_SLT;
            end
            else begin
              illegal_instr_o = 1'b1;
              reg_write_o     = 1'b0;
              wb_sel_o        = WB_NONE;
            end
          end

          3'b011: begin
            if (funct7_o == 7'b0000000) begin
              alu_op_o = ALU_SLTU;
            end
            else begin
              illegal_instr_o = 1'b1;
              reg_write_o     = 1'b0;
              wb_sel_o        = WB_NONE;
            end
          end

          3'b100: begin
            if (funct7_o == 7'b0000000) begin
              alu_op_o = ALU_XOR;
            end
            else begin
              illegal_instr_o = 1'b1;
              reg_write_o     = 1'b0;
              wb_sel_o        = WB_NONE;
            end
          end

          3'b101: begin
            unique case (funct7_o)
              7'b0000000: alu_op_o = ALU_SRL;
              7'b0100000: alu_op_o = ALU_SRA;
              default: begin
                illegal_instr_o = 1'b1;
                reg_write_o     = 1'b0;
                wb_sel_o        = WB_NONE;
              end
            endcase
          end

          3'b110: begin
            if (funct7_o == 7'b0000000) begin
              alu_op_o = ALU_OR;
            end
            else begin
              illegal_instr_o = 1'b1;
              reg_write_o     = 1'b0;
              wb_sel_o        = WB_NONE;
            end
          end

          3'b111: begin
            if (funct7_o == 7'b0000000) begin
              alu_op_o = ALU_AND;
            end
            else begin
              illegal_instr_o = 1'b1;
              reg_write_o     = 1'b0;
              wb_sel_o        = WB_NONE;
            end
          end

          default: begin
            illegal_instr_o = 1'b1;
            reg_write_o     = 1'b0;
            wb_sel_o        = WB_NONE;
          end
        endcase
      end

      // -------------------------------------------------------
      // Unsupported in this revision
      // -------------------------------------------------------
      OPCODE_MISC_MEM: begin
        illegal_instr_o = 1'b1;
      end

      OPCODE_SYSTEM: begin
        illegal_instr_o = 1'b1;
      end

      default: begin
        // ID-012 / EXC-001
        illegal_instr_o = 1'b1;
      end
    endcase
  end

endmodule
