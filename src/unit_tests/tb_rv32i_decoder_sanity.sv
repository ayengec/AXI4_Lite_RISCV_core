`timescale 1ns/1ps
module tb_rv32i_decoder_sanity;
  
  
  import rv32i_pkg::*;

  logic [31:0] instr_i;

  logic [6:0]  opcode_o;
  logic [4:0]  rs1_o;
  logic [4:0]  rs2_o;
  logic [4:0]  rd_o;
  logic [2:0]  funct3_o;
  logic [6:0]  funct7_o;

  logic [31:0] imm_i_type_o;
  logic [31:0] imm_s_type_o;
  logic [31:0] imm_b_type_o;
  logic [31:0] imm_u_type_o;
  logic [31:0] imm_j_type_o;

  logic        use_rs1_o;
  logic        use_rs2_o;
  logic        reg_write_o;
  logic        alu_src_imm_o;
  alu_op_e     alu_op_o;
  wb_sel_e     wb_sel_o;

  logic        is_branch_o;
  logic        is_jal_o;
  logic        is_jalr_o;
  branch_op_e  branch_op_o;

  logic        is_load_o;
  logic        is_store_o;
  mem_size_e   mem_size_o;
  logic        load_unsigned_o;

  logic        op_a_is_pc_o;
  logic        op_b_is_uimm_o;

  logic        illegal_instr_o;

  integer pass_count;
  integer fail_count;

  rv32i_decoder dut (
    .instr_i         (instr_i),
    .opcode_o        (opcode_o),
    .rs1_o           (rs1_o),
    .rs2_o           (rs2_o),
    .rd_o            (rd_o),
    .funct3_o        (funct3_o),
    .funct7_o        (funct7_o),
    .imm_i_type_o    (imm_i_type_o),
    .imm_s_type_o    (imm_s_type_o),
    .imm_b_type_o    (imm_b_type_o),
    .imm_u_type_o    (imm_u_type_o),
    .imm_j_type_o    (imm_j_type_o),
    .use_rs1_o       (use_rs1_o),
    .use_rs2_o       (use_rs2_o),
    .reg_write_o     (reg_write_o),
    .alu_src_imm_o   (alu_src_imm_o),
    .alu_op_o        (alu_op_o),
    .wb_sel_o        (wb_sel_o),
    .is_branch_o     (is_branch_o),
    .is_jal_o        (is_jal_o),
    .is_jalr_o       (is_jalr_o),
    .branch_op_o     (branch_op_o),
    .is_load_o       (is_load_o),
    .is_store_o      (is_store_o),
    .mem_size_o      (mem_size_o),
    .load_unsigned_o (load_unsigned_o),
    .op_a_is_pc_o    (op_a_is_pc_o),
    .op_b_is_uimm_o  (op_b_is_uimm_o),
    .illegal_instr_o (illegal_instr_o)
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

  task automatic check_u5;
    input [4:0] actual;
    input [4:0] expected;
    input [1023:0] msg;
    begin
      if (actual !== expected) begin
        fail_count = fail_count + 1;
        $display("[FAIL] %0s | expected=0x%02h actual=0x%02h", msg, expected, actual);
      end
      else begin
        pass_count = pass_count + 1;
        $display("[PASS] %0s", msg);
      end
    end
  endtask

  task automatic check_u3;
    input [2:0] actual;
    input [2:0] expected;
    input [1023:0] msg;
    begin
      if (actual !== expected) begin
        fail_count = fail_count + 1;
        $display("[FAIL] %0s | expected=0x%0h actual=0x%0h", msg, expected, actual);
      end
      else begin
        pass_count = pass_count + 1;
        $display("[PASS] %0s", msg);
      end
    end
  endtask

  task automatic check_u7;
    input [6:0] actual;
    input [6:0] expected;
    input [1023:0] msg;
    begin
      if (actual !== expected) begin
        fail_count = fail_count + 1;
        $display("[FAIL] %0s | expected=0x%0h actual=0x%0h", msg, expected, actual);
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

  task automatic check_aluop;
    input alu_op_e actual;
    input alu_op_e expected;
    input [1023:0] msg;
    begin
      if (actual !== expected) begin
        fail_count = fail_count + 1;
        $display("[FAIL] %0s | expected=%0d actual=%0d", msg, expected, actual);
      end
      else begin
        pass_count = pass_count + 1;
        $display("[PASS] %0s", msg);
      end
    end
  endtask

  task automatic check_branchop;
    input branch_op_e actual;
    input branch_op_e expected;
    input [1023:0] msg;
    begin
      if (actual !== expected) begin
        fail_count = fail_count + 1;
        $display("[FAIL] %0s | expected=%0d actual=%0d", msg, expected, actual);
      end
      else begin
        pass_count = pass_count + 1;
        $display("[PASS] %0s", msg);
      end
    end
  endtask

  task automatic check_wbsel;
    input wb_sel_e actual;
    input wb_sel_e expected;
    input [1023:0] msg;
    begin
      if (actual !== expected) begin
        fail_count = fail_count + 1;
        $display("[FAIL] %0s | expected=%0d actual=%0d", msg, expected, actual);
      end
      else begin
        pass_count = pass_count + 1;
        $display("[PASS] %0s", msg);
      end
    end
  endtask

  task automatic check_memsize;
    input mem_size_e actual;
    input mem_size_e expected;
    input [1023:0] msg;
    begin
      if (actual !== expected) begin
        fail_count = fail_count + 1;
        $display("[FAIL] %0s | expected=%0d actual=%0d", msg, expected, actual);
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
    $display("Starting tb_rv32i_decoder sanity test");
    $display("==============================================");

    // ----------------------------------------------------------
    // ADD x5, x6, x7
    //  funct7 rs2  rs1  funct3 rd   opcode
    // 0000000 00111 00110 000   00101 0110011
    // ----------------------------------------------------------
    instr_i = 32'b0000000_00111_00110_000_00101_0110011;
    #1;
    check_u7(opcode_o, 7'b0110011, "ADD: opcode");
    check_u5(rs1_o,    5'd6,       "ADD: rs1");
    check_u5(rs2_o,    5'd7,       "ADD: rs2");
    check_u5(rd_o,     5'd5,       "ADD: rd");
    check_u3(funct3_o, 3'b000,     "ADD: funct3");
    check_u7(funct7_o, 7'b0000000, "ADD: funct7");
    check_bit(use_rs1_o,     1'b1, "ADD: use_rs1");
    check_bit(use_rs2_o,     1'b1, "ADD: use_rs2");
    check_bit(reg_write_o,   1'b1, "ADD: reg_write");
    check_bit(alu_src_imm_o, 1'b0, "ADD: alu_src_imm");
    check_aluop(alu_op_o, ALU_ADD, "ADD: alu_op");
    check_wbsel(wb_sel_o, WB_ALU,  "ADD: wb_sel");
    check_bit(illegal_instr_o, 1'b0, "ADD: legal instruction");

    // ----------------------------------------------------------
    // SUB x8, x9, x10
    // ----------------------------------------------------------
    instr_i = 32'b0100000_01010_01001_000_01000_0110011;
    #1;
    check_aluop(alu_op_o, ALU_SUB, "SUB: alu_op");
    check_bit(reg_write_o, 1'b1,   "SUB: reg_write");
    check_bit(illegal_instr_o, 1'b0, "SUB: legal instruction");

    // ----------------------------------------------------------
    // ADDI x3, x4, -1
    // imm[11:0]=0xFFF
    // ----------------------------------------------------------
    instr_i = 32'b111111111111_00100_000_00011_0010011;
    #1;
    check_u7(opcode_o, 7'b0010011, "ADDI: opcode");
    check_u5(rs1_o,    5'd4,       "ADDI: rs1");
    check_u5(rd_o,     5'd3,       "ADDI: rd");
    check_u32(imm_i_type_o, 32'hFFFF_FFFF, "ADDI: sign-extended I-immediate");
    check_bit(alu_src_imm_o, 1'b1, "ADDI: alu_src_imm");
    check_aluop(alu_op_o, ALU_ADD, "ADDI: alu_op");
    check_wbsel(wb_sel_o, WB_ALU,  "ADDI: wb_sel");
    check_bit(illegal_instr_o, 1'b0, "ADDI: legal instruction");

    // ----------------------------------------------------------
    // SRAI x2, x1, 3
    // funct7 must be 0100000
    // ----------------------------------------------------------
    instr_i = 32'b0100000_00011_00001_101_00010_0010011;
    #1;
    check_aluop(alu_op_o, ALU_SRA, "SRAI: alu_op");
    check_bit(alu_src_imm_o, 1'b1, "SRAI: alu_src_imm");
    check_bit(illegal_instr_o, 1'b0, "SRAI: legal instruction");

    // ----------------------------------------------------------
    // LW x12, 8(x13)
    // ----------------------------------------------------------
    instr_i = 32'b000000001000_01101_010_01100_0000011;
    #1;
    check_bit(is_load_o,       1'b1,     "LW: is_load");
    check_bit(is_store_o,      1'b0,     "LW: is_store");
    check_memsize(mem_size_o,  MEM_WORD, "LW: mem_size");
    check_bit(load_unsigned_o, 1'b0,     "LW: signed/unsigned");
    check_wbsel(wb_sel_o,      WB_MEM,   "LW: wb_sel");
    check_bit(reg_write_o,     1'b1,     "LW: reg_write");
    check_bit(illegal_instr_o, 1'b0,     "LW: legal instruction");

    // ----------------------------------------------------------
    // SW x14, 12(x15)
    // imm = 12 = 0x00C
    // upper imm[11:5]=0000000 lower imm[4:0]=01100
    // ----------------------------------------------------------
    instr_i = 32'b0000000_01110_01111_010_01100_0100011;
    #1;
    check_bit(is_load_o,       1'b0,         "SW: is_load");
    check_bit(is_store_o,      1'b1,         "SW: is_store");
    check_memsize(mem_size_o,  MEM_WORD,     "SW: mem_size");
    check_u32(imm_s_type_o,    32'h0000_000C,"SW: S-immediate");
    check_bit(reg_write_o,     1'b0,         "SW: reg_write");
    check_bit(illegal_instr_o, 1'b0,         "SW: legal instruction");

    // ----------------------------------------------------------
    // BEQ x1, x2, +16
    // B-imm = 16
    // ----------------------------------------------------------
    instr_i = 32'b0000000_00010_00001_000_01000_1100011;
    #1;
    check_bit(is_branch_o,      1'b1,      "BEQ: is_branch");
    check_branchop(branch_op_o, BR_BEQ,    "BEQ: branch_op");
    check_u32(imm_b_type_o, 32'h0000_0008, "BEQ: B-immediate");
    check_bit(reg_write_o,      1'b0,      "BEQ: reg_write");
    check_bit(illegal_instr_o,  1'b0,      "BEQ: legal instruction");

    // ----------------------------------------------------------
    // JAL x1, +32
    // Simple representative J-type encoding
    // ----------------------------------------------------------
    instr_i = 32'b00000010000000000000_00001_1101111;
    #1;
    check_bit(is_jal_o,         1'b1,    "JAL: is_jal");
    check_bit(is_jalr_o,        1'b0,    "JAL: is_jalr");
    check_bit(reg_write_o,      1'b1,    "JAL: reg_write");
    check_wbsel(wb_sel_o,       WB_PC4,  "JAL: wb_sel");
    check_bit(illegal_instr_o,  1'b0,    "JAL: legal instruction");

    // ----------------------------------------------------------
    // JALR x1, x2, 4
    // funct3 must be 000
    // ----------------------------------------------------------
    instr_i = 32'b000000000100_00010_000_00001_1100111;
    #1;
    check_bit(is_jalr_o,        1'b1,    "JALR: is_jalr");
    check_bit(use_rs1_o,        1'b1,    "JALR: use_rs1");
    check_bit(reg_write_o,      1'b1,    "JALR: reg_write");
    check_wbsel(wb_sel_o,       WB_PC4,  "JALR: wb_sel");
    check_bit(illegal_instr_o,  1'b0,    "JALR: legal instruction");

    // ----------------------------------------------------------
    // LUI x9, 0x12345000
    // ----------------------------------------------------------
    instr_i = 32'h123454B7;
    #1;
    check_u7(opcode_o, 7'b0110111, "LUI: opcode");
    check_bit(reg_write_o,     1'b1,       "LUI: reg_write");
    check_aluop(alu_op_o,      ALU_COPY_B, "LUI: alu_op");
    check_bit(op_b_is_uimm_o,  1'b1,       "LUI: op_b_is_uimm");
    check_u32(imm_u_type_o,    32'h12345000, "LUI: U-immediate");
    check_bit(illegal_instr_o, 1'b0,       "LUI: legal instruction");

    // ----------------------------------------------------------
    // AUIPC x10, 0x00012000
    // ----------------------------------------------------------
    instr_i = 32'h00012517;
    #1;
    check_u7(opcode_o, 7'b0010111, "AUIPC: opcode");
    check_bit(reg_write_o,     1'b1,    "AUIPC: reg_write");
    check_aluop(alu_op_o,      ALU_ADD, "AUIPC: alu_op");
    check_bit(op_a_is_pc_o,    1'b1,    "AUIPC: op_a_is_pc");
    check_bit(op_b_is_uimm_o,  1'b1,    "AUIPC: op_b_is_uimm");
    check_bit(illegal_instr_o, 1'b0,    "AUIPC: legal instruction");

    // ----------------------------------------------------------
    // Illegal: unknown opcode
    // ----------------------------------------------------------
    instr_i = 32'hFFFF_FFFF;
    #1;
    check_bit(illegal_instr_o, 1'b1, "Illegal opcode: illegal asserted");

    // ----------------------------------------------------------
    // Illegal: bad JALR funct3
    // ----------------------------------------------------------
    instr_i = 32'b000000000100_00010_001_00001_1100111;
    #1;
    check_bit(illegal_instr_o, 1'b1, "Bad JALR funct3: illegal asserted");

    // ----------------------------------------------------------
    // Illegal: bad SLLI/SRLI/SRAI funct7 combination
    // Example: SLLI with illegal funct7
    // ----------------------------------------------------------
    instr_i = 32'b1111111_00011_00001_001_00010_0010011;
    #1;
    check_bit(illegal_instr_o, 1'b1, "Bad shift-immediate funct7: illegal asserted");

    $display("==============================================");
    $display("Decoder sanity finished | PASS=%0d FAIL=%0d", pass_count, fail_count);
    $display("==============================================");

    if (fail_count != 0) begin
      $fatal;
    end

    $finish;
  end
  
    initial begin
      $dumpfile("dump.vcd");
      $dumpvars(0, tb_rv32i_decoder_sanity);
    end

endmodule
