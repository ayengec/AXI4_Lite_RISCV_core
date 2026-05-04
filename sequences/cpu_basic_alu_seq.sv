// cpu_basic_alu_seq.sv
// Author: Alican Yengec
// Tests all R-type and I-type ALU operations.
// Results are stored to data memory for scoreboard checking.

class cpu_basic_alu_seq extends cpu_base_seq;
  `uvm_object_utils(cpu_basic_alu_seq)

  function new(string name = "cpu_basic_alu_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Building ALU test program", UVM_LOW)
    clear_program();

    // x1 = 0x0000_0200 (data memory base)
    add_instr(lui(5'd1, 20'h00000),
              "SETUP: LUI x1, 0 -> x1 upper bits cleared");
    add_instr(addi(5'd1, 5'd0, 12'h200),
              "SETUP: ADDI x1 = x0 + 0x200 -> data base 0x00000200");

    // Load test values into registers
    add_instr(addi(5'd2, 5'd0, 12'd10),
              "SETUP: ADDI x2 = x0 + 10 -> x2=10");
    add_instr(addi(5'd3, 5'd0, 12'd3),
              "SETUP: ADDI x3 = x0 + 3 -> x3=3");
    add_instr(addi(5'd4, 5'd0, -12'sd5),
              "SETUP: ADDI x4 = x0 - 5 -> x4=0xfffffffb");

    // --- R-type ALU operations ---
    // ADD: x5 = x2 + x3 = 13
    add_instr(add(5'd5, 5'd2, 5'd3),
              "ADD: x5 = x2 + x3 = 10 + 3 -> 13");
    add_instr(sw(5'd5, 5'd1, 12'h000),
              "CHECKPOINT: SW x5 -> MEM[0x200], expect 0x0000000d");

    // SUB: x6 = x2 - x3 = 7
    add_instr(sub(5'd6, 5'd2, 5'd3),
              "SUB: x6 = x2 - x3 = 10 - 3 -> 7");
    add_instr(sw(5'd6, 5'd1, 12'h004),
              "CHECKPOINT: SW x6 -> MEM[0x204], expect 0x00000007");

    // AND: x7 = x2 & x3 = 10 & 3 = 2
    add_instr(rv_r_type(7'b0000000, 5'd3, 5'd2, 3'b111, 5'd7, 7'b0110011),
              "AND: x7 = x2 & x3 = 10 & 3 -> 2");
    add_instr(sw(5'd7, 5'd1, 12'h008),
              "CHECKPOINT: SW x7 -> MEM[0x208], expect 0x00000002");

    // OR: x8 = x2 | x3 = 10 | 3 = 11
    add_instr(rv_r_type(7'b0000000, 5'd3, 5'd2, 3'b110, 5'd8, 7'b0110011),
              "OR: x8 = x2 | x3 = 10 | 3 -> 11");
    add_instr(sw(5'd8, 5'd1, 12'h00C),
              "CHECKPOINT: SW x8 -> MEM[0x20c], expect 0x0000000b");

    // XOR: x9 = x2 ^ x3 = 10 ^ 3 = 9
    add_instr(rv_r_type(7'b0000000, 5'd3, 5'd2, 3'b100, 5'd9, 7'b0110011),
              "XOR: x9 = x2 ^ x3 = 10 ^ 3 -> 9");
    add_instr(sw(5'd9, 5'd1, 12'h010),
              "CHECKPOINT: SW x9 -> MEM[0x210], expect 0x00000009");

    // SLL: x10 = x2 << x3 = 10 << 3 = 80
    add_instr(rv_r_type(7'b0000000, 5'd3, 5'd2, 3'b001, 5'd10, 7'b0110011),
              "SLL: x10 = x2 << x3 = 10 << 3 -> 80");
    add_instr(sw(5'd10, 5'd1, 12'h014),
              "CHECKPOINT: SW x10 -> MEM[0x214], expect 0x00000050");

    // SRL: x11 = x2 >> x3 = 10 >> 3 = 1
    add_instr(rv_r_type(7'b0000000, 5'd3, 5'd2, 3'b101, 5'd11, 7'b0110011),
              "SRL: x11 = x2 >> x3 = 10 >> 3 -> 1");
    add_instr(sw(5'd11, 5'd1, 12'h018),
              "CHECKPOINT: SW x11 -> MEM[0x218], expect 0x00000001");

    // SRA: x12 = x4 >>> x3 = -5 >>> 3
    add_instr(rv_r_type(7'b0100000, 5'd3, 5'd4, 3'b101, 5'd12, 7'b0110011),
              "SRA: x12 = signed(x4) >>> x3 = -5 >>> 3 -> 0xffffffff");
    add_instr(sw(5'd12, 5'd1, 12'h01C),
              "CHECKPOINT: SW x12 -> MEM[0x21c], expect 0xffffffff");

    // SLT: x13 = (x4 < x2) ? 1 : 0 = 1 (signed: -5 < 10)
    add_instr(rv_r_type(7'b0000000, 5'd2, 5'd4, 3'b010, 5'd13, 7'b0110011),
              "SLT: x13 = signed(x4 < x2) = (-5 < 10) -> 1");
    add_instr(sw(5'd13, 5'd1, 12'h020),
              "CHECKPOINT: SW x13 -> MEM[0x220], expect 0x00000001");

    // SLTU: x14 = (x4 < x2) ? 1 : 0 = 0 (unsigned: 0xFFFFFFFB > 10)
    add_instr(rv_r_type(7'b0000000, 5'd2, 5'd4, 3'b011, 5'd14, 7'b0110011),
              "SLTU: x14 = unsigned(x4 < x2) = (0xfffffffb < 10) -> 0");
    add_instr(sw(5'd14, 5'd1, 12'h024),
              "CHECKPOINT: SW x14 -> MEM[0x224], expect 0x00000000");

    // --- I-type ALU operations ---
    // ADDI: x15 = x2 + 100 = 110
    add_instr(addi(5'd15, 5'd2, 12'd100),
              "ADDI: x15 = x2 + 100 = 10 + 100 -> 110");
    add_instr(sw(5'd15, 5'd1, 12'h028),
              "CHECKPOINT: SW x15 -> MEM[0x228], expect 0x0000006e");

    // XORI: x16 = x2 ^ 0xFF = 10 ^ 255 = 245
    add_instr(rv_i_type(12'h0FF, 5'd2, 3'b100, 5'd16, 7'b0010011),
              "XORI: x16 = x2 ^ 0xff = 10 ^ 255 -> 245");
    add_instr(sw(5'd16, 5'd1, 12'h02C),
              "CHECKPOINT: SW x16 -> MEM[0x22c], expect 0x000000f5");

    // ORI: x17 = x2 | 0xF0 = 10 | 240 = 250
    add_instr(rv_i_type(12'h0F0, 5'd2, 3'b110, 5'd17, 7'b0010011),
              "ORI: x17 = x2 | 0xf0 = 10 | 240 -> 250");
    add_instr(sw(5'd17, 5'd1, 12'h030),
              "CHECKPOINT: SW x17 -> MEM[0x230], expect 0x000000fa");

    // ANDI: x18 = x2 & 0x0F = 10 & 15 = 10
    add_instr(rv_i_type(12'h00F, 5'd2, 3'b111, 5'd18, 7'b0010011),
              "ANDI: x18 = x2 & 0x0f = 10 & 15 -> 10");
    add_instr(sw(5'd18, 5'd1, 12'h034),
              "CHECKPOINT: SW x18 -> MEM[0x234], expect 0x0000000a");

    // SLLI: x19 = x2 << 4 = 10 << 4 = 160
    add_instr(rv_i_type(12'h004, 5'd2, 3'b001, 5'd19, 7'b0010011),
              "SLLI: x19 = x2 << 4 = 10 << 4 -> 160");
    add_instr(sw(5'd19, 5'd1, 12'h038),
              "CHECKPOINT: SW x19 -> MEM[0x238], expect 0x000000a0");

    // SRLI: x20 = x2 >> 1 = 10 >> 1 = 5
    add_instr(rv_i_type(12'h001, 5'd2, 3'b101, 5'd20, 7'b0010011),
              "SRLI: x20 = x2 >> 1 = 10 >> 1 -> 5");
    add_instr(sw(5'd20, 5'd1, 12'h03C),
              "CHECKPOINT: SW x20 -> MEM[0x23c], expect 0x00000005");

    // SRAI: x21 = x4 >>> 1 = -5 >>> 1
    add_instr(rv_i_type(12'h401, 5'd4, 3'b101, 5'd21, 7'b0010011),
              "SRAI: x21 = signed(x4) >>> 1 = -5 >>> 1 -> 0xfffffffd");
    add_instr(sw(5'd21, 5'd1, 12'h040),
              "CHECKPOINT: SW x21 -> MEM[0x240], expect 0xfffffffd");

    // LUI: x22 = 0xDEAD_0000
    add_instr(lui(5'd22, 20'hDEAD0),
              "LUI: x22 = 0xdead0 << 12 -> 0xdead0000");
    add_instr(sw(5'd22, 5'd1, 12'h044),
              "CHECKPOINT: SW x22 -> MEM[0x244], expect 0xdead0000");

    // AUIPC: x23 = PC + 0x1000_0000
    add_instr({20'h10000, 5'd23, 7'b0010111},
              "AUIPC: x23 = current PC + 0x10000000 -> expect 0x100000a4");
    add_instr(sw(5'd23, 5'd1, 12'h048),
              "CHECKPOINT: SW x23 -> MEM[0x248], expect 0x100000a4");

    // End with illegal instruction to halt CPU
    add_instr(illegal_instr(),
              "HALT: illegal instruction 0x00000000 stops CPU");

    `uvm_info(get_type_name(), $sformatf("ALU test program: %0d instructions", program_size), UVM_LOW)
  endtask
endclass : cpu_basic_alu_seq
