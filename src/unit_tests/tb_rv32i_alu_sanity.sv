`timescale 1ns/1ps

module tb_rv32i_alu_sanity;
  
  logic [31:0] op_a_i;
  logic [31:0] op_b_i;
  alu_op_e     alu_op_i;

  logic [31:0] result_o;
  logic        cmp_eq_o;
  logic        cmp_lt_o;
  logic        cmp_ltu_o;

  integer pass_count;
  integer fail_count;

  rv32i_alu dut (
    .alu_op_i  (alu_op_i),
    .op_a_i    (op_a_i),
    .op_b_i    (op_b_i),
    .result_o  (result_o),
    .cmp_eq_o  (cmp_eq_o),
    .cmp_lt_o  (cmp_lt_o),
    .cmp_ltu_o (cmp_ltu_o)
  );

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

  initial begin
    pass_count = 0;
    fail_count = 0;

    $display("==============================================");
    $display("Starting tb_rv32i_alu sanity test");
    $display("==============================================");

    // ----------------------------------------------------------
    // ALU-001 : ADD
    // ----------------------------------------------------------
    alu_op_i = ALU_ADD;
    op_a_i   = 32'h0000_0005;
    op_b_i   = 32'h0000_0007;
    #1;
    check_u32(result_o, 32'h0000_000C, "ALU-001: ADD result");
    check_bit(cmp_eq_o, 1'b0, "ADD: cmp_eq");
    check_bit(cmp_lt_o, 1'b1, "ADD inputs: cmp_lt signed");
    check_bit(cmp_ltu_o,1'b1, "ADD inputs: cmp_ltu unsigned");

    // ----------------------------------------------------------
    // ALU-002 : SUB
    // ----------------------------------------------------------
    alu_op_i = ALU_SUB;
    op_a_i   = 32'h0000_0009;
    op_b_i   = 32'h0000_0004;
    #1;
    check_u32(result_o, 32'h0000_0005, "ALU-002: SUB result");

    // ----------------------------------------------------------
    // ALU-003 : ADDI path uses same ADD op
    // ----------------------------------------------------------
    alu_op_i = ALU_ADD;
    op_a_i   = 32'hFFFF_FFFF;
    op_b_i   = 32'h0000_0001;
    #1;
    check_u32(result_o, 32'h0000_0000, "ALU-003: ADD wraparound result");

    // ----------------------------------------------------------
    // ALU-004 : AND
    // ----------------------------------------------------------
    alu_op_i = ALU_AND;
    op_a_i   = 32'hF0F0_AA55;
    op_b_i   = 32'h0FF0_0F5A;
    #1;
    check_u32(result_o, 32'h00F0_0A50, "ALU-004: AND result");

    // ----------------------------------------------------------
    // ALU-005 : OR
    // ----------------------------------------------------------
    alu_op_i = ALU_OR;
    op_a_i   = 32'hF0F0_AA55;
    op_b_i   = 32'h0FF0_0F5A;
    #1;
    check_u32(result_o, 32'hFFF0_AF5F, "ALU-005: OR result");

    // ----------------------------------------------------------
    // ALU-006 : XOR
    // ----------------------------------------------------------
    alu_op_i = ALU_XOR;
    op_a_i   = 32'hAAAA_5555;
    op_b_i   = 32'hFFFF_0000;
    #1;
    check_u32(result_o, 32'h5555_5555, "ALU-006: XOR result");

    // ----------------------------------------------------------
    // ALU-007 : SLL
    // ----------------------------------------------------------
    alu_op_i = ALU_SLL;
    op_a_i   = 32'h0000_0003;
    op_b_i   = 32'h0000_0004;
    #1;
    check_u32(result_o, 32'h0000_0030, "ALU-007: SLL result");

    // ----------------------------------------------------------
    // ALU-008 : SRL
    // ----------------------------------------------------------
    alu_op_i = ALU_SRL;
    op_a_i   = 32'h8000_0000;
    op_b_i   = 32'h0000_0004;
    #1;
    check_u32(result_o, 32'h0800_0000, "ALU-008: SRL result");

    // ----------------------------------------------------------
    // ALU-009 : SRA
    // ----------------------------------------------------------
    alu_op_i = ALU_SRA;
    op_a_i   = 32'h8000_0000;
    op_b_i   = 32'h0000_0004;
    #1;
    check_u32(result_o, 32'hF800_0000, "ALU-009: SRA result");

    // ----------------------------------------------------------
    // ALU-010 : SLT signed
    // ----------------------------------------------------------
    alu_op_i = ALU_SLT;
    op_a_i   = 32'hFFFF_FFFF; // -1
    op_b_i   = 32'h0000_0001; // +1
    #1;
    check_u32(result_o, 32'h0000_0001, "ALU-010: SLT result");
    check_bit(cmp_lt_o, 1'b1, "ALU-010: cmp_lt signed");

    // ----------------------------------------------------------
    // ALU-011 : SLTU unsigned
    // ----------------------------------------------------------
    alu_op_i = ALU_SLTU;
    op_a_i   = 32'h0000_0001;
    op_b_i   = 32'hFFFF_FFFF;
    #1;
    check_u32(result_o, 32'h0000_0001, "ALU-011: SLTU result");
    check_bit(cmp_ltu_o, 1'b1, "ALU-011: cmp_ltu unsigned");

    // ----------------------------------------------------------
    // ALU-012 : SLTI uses signed compare path
    // ----------------------------------------------------------
    alu_op_i = ALU_SLT;
    op_a_i   = 32'h8000_0000; // negative
    op_b_i   = 32'h0000_0000;
    #1;
    check_u32(result_o, 32'h0000_0001, "ALU-012: signed less-than result");

    // ----------------------------------------------------------
    // ALU-013 : SLTIU uses unsigned compare path
    // ----------------------------------------------------------
    alu_op_i = ALU_SLTU;
    op_a_i   = 32'h8000_0000;
    op_b_i   = 32'h0000_0001;
    #1;
    check_u32(result_o, 32'h0000_0000, "ALU-013: unsigned less-than result");

    // ----------------------------------------------------------
    // ALU-014 : LUI path via COPY_B
    // ----------------------------------------------------------
    alu_op_i = ALU_COPY_B;
    op_a_i   = 32'hDEAD_BEEF;
    op_b_i   = 32'h1234_5000;
    #1;
    check_u32(result_o, 32'h1234_5000, "ALU-014: COPY_B result");

    // ----------------------------------------------------------
    // ALU-015 : AUIPC path via ADD
    // ----------------------------------------------------------
    alu_op_i = ALU_ADD;
    op_a_i   = 32'h0000_1000; // PC
    op_b_i   = 32'h0001_2000; // U-imm
    #1;
    check_u32(result_o, 32'h0001_3000, "ALU-015: AUIPC-style add result");

    // ----------------------------------------------------------
    // Equality compare
    // ----------------------------------------------------------
    alu_op_i = ALU_ADD;
    op_a_i   = 32'hCAFE_BABE;
    op_b_i   = 32'hCAFE_BABE;
    #1;
    check_bit(cmp_eq_o, 1'b1, "Compare: cmp_eq when operands equal");
    check_bit(cmp_lt_o, 1'b0, "Compare: cmp_lt when operands equal");
    check_bit(cmp_ltu_o,1'b0, "Compare: cmp_ltu when operands equal");

    $display("==============================================");
    $display("ALU sanity finished | PASS=%0d FAIL=%0d", pass_count, fail_count);
    $display("==============================================");

    if (fail_count != 0) begin
      $fatal;
    end

    $finish;
  end
  
    initial begin
      $dumpfile("dump.vcd");
      $dumpvars(0, tb_rv32i_alu_sanity);
    end

endmodule
