//==============================================================
// File: rv32i_branch_unit.sv
// Description: RV32I branch and jump control unit
//==============================================================

import rv32i_pkg::*;

module rv32i_branch_unit (
  input  logic [31:0] pc_i,
  input  logic [31:0] rs1_i,

  input  logic [31:0] b_imm_i,
  input  logic [31:0] j_imm_i,
  input  logic [31:0] i_imm_i,

  input  logic        is_branch_i,
  input  logic        is_jal_i,
  input  logic        is_jalr_i,
  input  branch_op_e  branch_op_i,

  input  logic        cmp_eq_i,
  input  logic        cmp_lt_i,
  input  logic        cmp_ltu_i,

  output logic        branch_taken_o,
  output logic [31:0] branch_target_o,
  output logic [31:0] jal_target_o,
  output logic [31:0] jalr_target_o,

  output logic        branch_target_misaligned_o,
  output logic        jal_target_misaligned_o,
  output logic        jalr_target_misaligned_o
);

  logic [31:0] jalr_sum;

  always_comb begin
    branch_taken_o = 1'b0;

    if (is_branch_i) begin
      unique case (branch_op_i)
        BR_BEQ:  branch_taken_o = cmp_eq_i;   // BRN-001
        BR_BNE:  branch_taken_o = ~cmp_eq_i;  // BRN-002
        BR_BLT:  branch_taken_o = cmp_lt_i;   // BRN-003
        BR_BGE:  branch_taken_o = ~cmp_lt_i;  // BRN-005
        BR_BLTU: branch_taken_o = cmp_ltu_i;  // BRN-004
        BR_BGEU: branch_taken_o = ~cmp_ltu_i; // BRN-006
        default: branch_taken_o = 1'b0;
      endcase
    end
  end

  assign branch_target_o = pc_i + b_imm_i;        // BRN-001, BRN-002, BRN-003, BRN-004, BRN-005, BRN-006
  assign jal_target_o    = pc_i + j_imm_i;        // JMP-001

  assign jalr_sum        = rs1_i + i_imm_i;
  assign jalr_target_o   = {jalr_sum[31:1], 1'b0}; // JMP-002 : bit[0] cleared

  // Alignment checks
  assign branch_target_misaligned_o = |branch_target_o[1:0]; // BRN-007
  assign jal_target_misaligned_o    = |jal_target_o[1:0];    // implied by IF/EXC alignment rules
  assign jalr_target_misaligned_o   = |jalr_target_o[1:0];   // implied by IF/EXC alignment rules

endmodule
