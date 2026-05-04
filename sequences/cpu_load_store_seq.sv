// cpu_load_store_seq.sv
// Author: Alican Yengec
// Tests all load/store operations: LW, LH, LB, LHU, LBU, SW, SH, SB

class cpu_load_store_seq extends cpu_base_seq;
  `uvm_object_utils(cpu_load_store_seq)

  function new(string name = "cpu_load_store_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Building load/store test program", UVM_LOW)
    clear_program();

    // x1 = 0x200 (data base)
    add_instr(addi(5'd1, 5'd0, 12'h200),
              "SETUP: ADDI x1 = x0 + 0x200 -> data base 0x00000200");

    // x2 = 0xDEADAEEF because ADDI sign-extends 12'hEEF as a negative immediate.
    add_instr(lui(5'd2, 20'hDEADB),
              "SETUP: LUI x2 = 0xdeadb << 12 -> 0xdeadb000");
    add_instr(rv_i_type(12'hEEF, 5'd2, 3'b000, 5'd2, 7'b0010011),
              "SETUP: ADDI x2 = x2 + signext(0xeef) -> 0xdeadaeef");

    // SW: store x2 to MEM[0x200]
    add_instr(sw(5'd2, 5'd1, 12'h000),
              "SW: store x2 -> MEM[0x200], expect word 0xdeadaeef");

    // LW: x3 = MEM[0x200] (should be the value stored)
    add_instr(lw(5'd3, 5'd1, 12'h000),
              "LW: x3 = MEM[0x200], expect 0xdeadaeef");

    // Store x3 to MEM[0x204] for verification
    add_instr(sw(5'd3, 5'd1, 12'h004),
              "CHECKPOINT: SW x3 -> MEM[0x204], expect 0xdeadaeef");

    // Test SH (store halfword)
    add_instr(addi(5'd4, 5'd0, 12'h7FF),
              "SETUP: ADDI x4 = x0 + 0x7ff -> 2047");
    // SH: store x4[15:0] to MEM[0x208]
    add_instr(rv_s_type(12'h008, 5'd4, 5'd1, 3'b001, 7'b0100011),
              "SH: store x4[15:0] -> MEM[0x208], expect low halfword 0x07ff");

    // LH: x5 = MEM[0x208] (signed halfword)
    add_instr(rv_i_type(12'h008, 5'd1, 3'b001, 5'd5, 7'b0000011),
              "LH: x5 = signed halfword MEM[0x208], expect 0x000007ff");
    add_instr(sw(5'd5, 5'd1, 12'h00C),
              "CHECKPOINT: SW x5 -> MEM[0x20c], expect 0x000007ff");

    // LHU: x6 = MEM[0x208] (unsigned halfword)
    add_instr(rv_i_type(12'h008, 5'd1, 3'b101, 5'd6, 7'b0000011),
              "LHU: x6 = unsigned halfword MEM[0x208], expect 0x000007ff");
    add_instr(sw(5'd6, 5'd1, 12'h010),
              "CHECKPOINT: SW x6 -> MEM[0x210], expect 0x000007ff");

    // Test SB (store byte)
    add_instr(addi(5'd7, 5'd0, 12'hFF),
              "SETUP: ADDI x7 = x0 + 0xff -> 255");
    // Clear target memory first
    add_instr(sw(5'd0, 5'd1, 12'h014),
              "SETUP: clear MEM[0x214] before byte store");
    // SB: store x7[7:0] to MEM[0x214]
    add_instr(rv_s_type(12'h014, 5'd7, 5'd1, 3'b000, 7'b0100011),
              "SB: store x7[7:0] -> MEM[0x214], expect byte 0xff");

    // LB: x8 = MEM[0x214] (signed byte, should be 0xFFFFFFFF = -1)
    add_instr(rv_i_type(12'h014, 5'd1, 3'b000, 5'd8, 7'b0000011),
              "LB: x8 = signed byte MEM[0x214], expect 0xffffffff");
    add_instr(sw(5'd8, 5'd1, 12'h018),
              "CHECKPOINT: SW x8 -> MEM[0x218], expect 0xffffffff");

    // LBU: x9 = MEM[0x214] (unsigned byte, should be 0x000000FF = 255)
    add_instr(rv_i_type(12'h014, 5'd1, 3'b100, 5'd9, 7'b0000011),
              "LBU: x9 = unsigned byte MEM[0x214], expect 0x000000ff");
    add_instr(sw(5'd9, 5'd1, 12'h01C),
              "CHECKPOINT: SW x9 -> MEM[0x21c], expect 0x000000ff");

    // Test SH to upper halfword (offset+2)
    add_instr(sw(5'd0, 5'd1, 12'h020),
              "SETUP: clear MEM[0x220] before upper-halfword store");
    add_instr(addi(5'd10, 5'd0, 12'd99),
              "SETUP: ADDI x10 = 99");
    add_instr(addi(5'd11, 5'd1, 12'h002),
              "SETUP: ADDI x11 = x1 + 2 -> address 0x202");
    // SH to addr 0x222 (upper halfword of 0x220)
    add_instr(rv_s_type(12'h020, 5'd10, 5'd11, 3'b001, 7'b0100011),
              "SH: store x10[15:0] -> MEM[0x222], expect word 0x00630000 at 0x220");
    // LW whole word from 0x220
    add_instr(lw(5'd12, 5'd1, 12'h020),
              "LW: x12 = MEM[0x220], expect 0x00630000");
    add_instr(sw(5'd12, 5'd1, 12'h024),
              "CHECKPOINT: SW x12 -> MEM[0x224], expect 0x00630000");

    // End with illegal instruction
    add_instr(illegal_instr(),
              "HALT: illegal instruction 0x00000000 stops CPU");

    `uvm_info(get_type_name(), $sformatf("Load/Store test: %0d instructions", program_size), UVM_LOW)
  endtask
endclass : cpu_load_store_seq
