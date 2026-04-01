`timescale 1ns/1ps

import rv32i_pkg::*;

module tb_rv32i_branch_unit_sanity;

  logic [31:0] pc_i;
  logic [31:0] rs1_i;

  logic [31:0] b_imm_i;
  logic [31:0] j_imm_i;
  logic [31:0] i_imm_i;

  logic        is_branch_i;
  logic        is_jal_i;
  logic        is_jalr_i;
  branch_op_e  branch_op_i;

  logic        cmp_eq_i;
  logic        cmp_lt_i;
  logic        cmp_ltu_i;

  logic        branch_taken_o;
  logic [31:0] branch_target_o;
  logic [31:0] jal_target_o;
  logic [31:0] jalr_target_o;

  logic        branch_target_misaligned_o;
  logic        jal_target_misaligned_o;
  logic        jalr_target_misaligned_o;

  integer pass_count;
  integer fail_count;

  rv32i_branch_unit dut (
    .pc_i                       (pc_i),
    .rs1_i                      (rs1_i),
    .b_imm_i                    (b_imm_i),
    .j_imm_i                    (j_imm_i),
    .i_imm_i                    (i_imm_i),
    .is_branch_i                (is_branch_i),
    .is_jal_i                   (is_jal_i),
    .is_jalr_i                  (is_jalr_i),
    .branch_op_i                (branch_op_i),
    .cmp_eq_i                   (cmp_eq_i),
    .cmp_lt_i                   (cmp_lt_i),
    .cmp_ltu_i                  (cmp_ltu_i),
    .branch_taken_o             (branch_taken_o),
    .branch_target_o            (branch_target_o),
    .jal_target_o               (jal_target_o),
    .jalr_target_o              (jalr_target_o),
    .branch_target_misaligned_o (branch_target_misaligned_o),
    .jal_target_misaligned_o    (jal_target_misaligned_o),
    .jalr_target_misaligned_o   (jalr_target_misaligned_o)
  );

  task automatic check_bit;
    input actual;
    input expected;
    input [1023:0] msg;
    begin
      if (actual !== expected) begin
        fail_count = fail_count + 1;
        $display("[FAIL] %0s | expected=%0b actual=%0b", msg, expected, actual);
      end
      else begin
        pass_count = pass_count + 1;
        $display("[PASS] %0s", msg);
      end
    end
  endtask

  task automatic check_u32;
    input [31:0] actual;
    input [31:0] expected;
    input [1023:0] msg;
    begin
      if (actual !== expected) begin
        fail_count = fail_count + 1;
        $display("[FAIL] %0s | expected=0x%08h actual=0x%08h", msg, expected, actual);
      end
      else begin
        pass_count = pass_count + 1;
        $display("[PASS] %0s", msg);
      end
    end
  endtask

  task automatic clear_inputs;
    begin
      pc_i        = 32'h0000_0000;
      rs1_i       = 32'h0000_0000;
      b_imm_i     = 32'h0000_0000;
      j_imm_i     = 32'h0000_0000;
      i_imm_i     = 32'h0000_0000;
      is_branch_i = 1'b0;
      is_jal_i    = 1'b0;
      is_jalr_i   = 1'b0;
      branch_op_i = BR_NONE;
      cmp_eq_i    = 1'b0;
      cmp_lt_i    = 1'b0;
      cmp_ltu_i   = 1'b0;
    end
  endtask

  initial begin
    pass_count = 0;
    fail_count = 0;

    $display("==============================================");
    $display("Starting tb_rv32i_branch_unit sanity test");
    $display("==============================================");

    // ----------------------------------------------------------
    // BRN-001 : BEQ taken, aligned target
    // ----------------------------------------------------------
    clear_inputs();
    pc_i        = 32'h0000_1000;
    b_imm_i     = 32'h0000_0010;
    is_branch_i = 1'b1;
    branch_op_i = BR_BEQ;
    cmp_eq_i    = 1'b1;
    #1;
    check_bit(branch_taken_o, 1'b1, "BRN-001: BEQ taken");
    check_u32(branch_target_o, 32'h0000_1010, "BRN-001: branch target");
    check_bit(branch_target_misaligned_o, 1'b0, "BRN-007: aligned branch target flag");

    // ----------------------------------------------------------
    // BRN-007 : misaligned branch target
    // ----------------------------------------------------------
    clear_inputs();
    pc_i        = 32'h0000_1000;
    b_imm_i     = 32'h0000_0002;
    is_branch_i = 1'b1;
    branch_op_i = BR_BEQ;
    cmp_eq_i    = 1'b1;
    #1;
    check_u32(branch_target_o, 32'h0000_1002, "BRN-007: misaligned branch target value");
    check_bit(branch_target_misaligned_o, 1'b1, "BRN-007: misaligned branch target flag");

    // ----------------------------------------------------------
    // BRN-001 : BEQ not taken
    // ----------------------------------------------------------
    clear_inputs();
    is_branch_i = 1'b1;
    branch_op_i = BR_BEQ;
    cmp_eq_i    = 1'b0;
    #1;
    check_bit(branch_taken_o, 1'b0, "BRN-001: BEQ not taken");

    // ----------------------------------------------------------
    // BRN-002 : BNE taken
    // ----------------------------------------------------------
    clear_inputs();
    is_branch_i = 1'b1;
    branch_op_i = BR_BNE;
    cmp_eq_i    = 1'b0;
    #1;
    check_bit(branch_taken_o, 1'b1, "BRN-002: BNE taken");

    // ----------------------------------------------------------
    // BRN-003 : BLT taken
    // ----------------------------------------------------------
    clear_inputs();
    is_branch_i = 1'b1;
    branch_op_i = BR_BLT;
    cmp_lt_i    = 1'b1;
    #1;
    check_bit(branch_taken_o, 1'b1, "BRN-003: BLT taken");

    // ----------------------------------------------------------
    // BRN-005 : BGE taken
    // ----------------------------------------------------------
    clear_inputs();
    is_branch_i = 1'b1;
    branch_op_i = BR_BGE;
    cmp_lt_i    = 1'b0;
    #1;
    check_bit(branch_taken_o, 1'b1, "BRN-005: BGE taken when not less");

    // ----------------------------------------------------------
    // BRN-004 : BLTU taken
    // ----------------------------------------------------------
    clear_inputs();
    is_branch_i = 1'b1;
    branch_op_i = BR_BLTU;
    cmp_ltu_i   = 1'b1;
    #1;
    check_bit(branch_taken_o, 1'b1, "BRN-004: BLTU taken");

    // ----------------------------------------------------------
    // BRN-006 : BGEU taken
    // ----------------------------------------------------------
    clear_inputs();
    is_branch_i = 1'b1;
    branch_op_i = BR_BGEU;
    cmp_ltu_i   = 1'b0;
    #1;
    check_bit(branch_taken_o, 1'b1, "BRN-006: BGEU taken when not less");

    // ----------------------------------------------------------
    // JMP-001 : JAL target
    // ----------------------------------------------------------
    clear_inputs();
    pc_i     = 32'h0000_2000;
    j_imm_i  = 32'h0000_0040;
    is_jal_i = 1'b1;
    #1;
    check_u32(jal_target_o, 32'h0000_2040, "JMP-001: JAL target");
    check_bit(jal_target_misaligned_o, 1'b0, "JAL aligned target");

    // ----------------------------------------------------------
    // JMP-002 : JALR target with bit0 clear
    // ----------------------------------------------------------
    clear_inputs();
    rs1_i      = 32'h0000_3003;
    i_imm_i    = 32'h0000_0006;
    is_jalr_i  = 1'b1;
    #1;
    check_u32(jalr_target_o, 32'h0000_3008, "JMP-002: JALR target with bit0 cleared");
    check_bit(jalr_target_misaligned_o, 1'b0, "JALR aligned after bit0 clear");

    // ----------------------------------------------------------
    // JAL misaligned target flag
    // ----------------------------------------------------------
    clear_inputs();
    pc_i     = 32'h0000_1000;
    j_imm_i  = 32'h0000_0002;
    is_jal_i = 1'b1;
    #1;
    check_u32(jal_target_o, 32'h0000_1002, "JAL: target value");
    check_bit(jal_target_misaligned_o, 1'b1, "JAL: misaligned target flag");

    // ----------------------------------------------------------
    // JALR misaligned target flag after bit0 clear
    // ----------------------------------------------------------
    clear_inputs();
    rs1_i      = 32'h0000_0005;
    i_imm_i    = 32'h0000_0001;
    is_jalr_i  = 1'b1;
    #1;
    check_u32(jalr_target_o, 32'h0000_0006, "JALR: target after bit0 clear");
    check_bit(jalr_target_misaligned_o, 1'b1, "JALR: misaligned target flag");

    // ----------------------------------------------------------
    // BR_NONE / inactive control
    // ----------------------------------------------------------
    clear_inputs();
    pc_i    = 32'h0000_4000;
    b_imm_i = 32'h0000_0020;
    #1;
    check_bit(branch_taken_o, 1'b0, "BR_NONE: no branch taken");
    check_u32(branch_target_o, 32'h0000_4020, "Branch target still computes combinationally");

    $display("==============================================");
    $display("Branch unit sanity finished | PASS=%0d FAIL=%0d", pass_count, fail_count);
    $display("==============================================");

    if (fail_count != 0) begin
      $fatal;
    end

    $finish;
  end

    initial begin
      $dumpfile("dump.vcd");
      $dumpvars(0, tb_rv32i_branch_unit_sanity);
    end

endmodule
