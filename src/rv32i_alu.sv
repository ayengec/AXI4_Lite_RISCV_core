//==============================================================
// File: rv32i_alu.sv
// Description: RV32I Arithmetic Logic Unit
//==============================================================

import rv32i_pkg::*;

module rv32i_alu (
  input  alu_op_e     alu_op_i,
  input  logic [31:0] op_a_i,
  input  logic [31:0] op_b_i,

  output logic [31:0] result_o,
  output logic        cmp_eq_o,
  output logic        cmp_lt_o,
  output logic        cmp_ltu_o
);

  logic signed [31:0] op_a_signed;
  logic signed [31:0] op_b_signed;

  assign op_a_signed = signed'(op_a_i);
  assign op_b_signed = signed'(op_b_i);

  // Comparison helpers for branch/control logic
  assign cmp_eq_o  = (op_a_i == op_b_i);          // BRN-001, BRN-002
  assign cmp_lt_o  = (op_a_signed < op_b_signed); // BRN-003, BRN-005, ALU-010, ALU-012
  assign cmp_ltu_o = (op_a_i < op_b_i);           // BRN-004, BRN-006, ALU-011, ALU-013

  always_comb begin
    result_o = 32'h0000_0000;

    unique case (alu_op_i)

      ALU_ADD: begin
        result_o = op_a_i + op_b_i;               // ALU-001, ALU-003, ALU-015
      end

      ALU_SUB: begin
        result_o = op_a_i - op_b_i;               // ALU-002
      end

      ALU_AND: begin
        result_o = op_a_i & op_b_i;               // ALU-004
      end

      ALU_OR: begin
        result_o = op_a_i | op_b_i;               // ALU-005
      end

      ALU_XOR: begin
        result_o = op_a_i ^ op_b_i;               // ALU-006
      end

      ALU_SLL: begin
        result_o = op_a_i << op_b_i[4:0];         // ALU-007
      end

      ALU_SRL: begin
        result_o = op_a_i >> op_b_i[4:0];         // ALU-008
      end

      ALU_SRA: begin
        result_o = logic'(op_a_signed >>> op_b_i[4:0]); // ALU-009
      end

      ALU_SLT: begin
        result_o = {31'd0, (op_a_signed < op_b_signed)}; // ALU-010, ALU-012
      end

      ALU_SLTU: begin
        result_o = {31'd0, (op_a_i < op_b_i)};    // ALU-011, ALU-013
      end

      ALU_COPY_B: begin
        result_o = op_b_i;                        // ALU-014
      end

      default: begin
        result_o = 32'h0000_0000;
      end
    endcase
  end

endmodule
