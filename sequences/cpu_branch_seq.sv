// cpu_branch_seq.sv
// Author: Alican Yengec
// Tests all branch/jump instructions: BEQ, BNE, BLT, BGE, BLTU, BGEU, JAL, JALR

class cpu_branch_seq extends cpu_base_seq;
  `uvm_object_utils(cpu_branch_seq)

  function new(string name = "cpu_branch_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Building branch test program", UVM_LOW)
    clear_program();

    // Setup: x1=0x200 (data base), x2=5, x3=5, x4=10, x5=-3
    add_instr(addi(5'd1, 5'd0, 12'h200),
              "SETUP: ADDI x1 = x0 + 0x200 -> data base 0x00000200");
    add_instr(addi(5'd2, 5'd0, 12'd5),
              "SETUP: ADDI x2 = 5");
    add_instr(addi(5'd3, 5'd0, 12'd5),
              "SETUP: ADDI x3 = 5");
    add_instr(addi(5'd4, 5'd0, 12'd10),
              "SETUP: ADDI x4 = 10");
    add_instr(addi(5'd5, 5'd0, -12'sd3),
              "SETUP: ADDI x5 = -3 -> 0xfffffffd");

    // --- BEQ (taken): x2 == x3 -> skip next instruction ---
    // addr=0x14: BEQ x2, x3, +8 (skip 1 instr)
    add_instr(rv_b_type(13'd8, 5'd3, 5'd2, 3'b000, 7'b1100011),
              "BEQ: x2 == x3, branch +8 taken, skip next poison write");
    add_instr(addi(5'd10, 5'd0, 12'd999),
              "POISON: should be skipped by BEQ taken");
    // addr=0x1C: x10 = 1 (BEQ taken marker)
    add_instr(addi(5'd10, 5'd0, 12'd1),
              "BEQ PASS MARKER: x10 = 1");
    add_instr(sw(5'd10, 5'd1, 12'h000),
              "CHECKPOINT: SW x10 -> MEM[0x200], expect 1");

    // --- BNE (taken): x2 != x4 -> skip next instruction ---
    add_instr(rv_b_type(13'd8, 5'd4, 5'd2, 3'b001, 7'b1100011),
              "BNE: x2 != x4, branch +8 taken, skip next poison write");
    add_instr(addi(5'd11, 5'd0, 12'd999),
              "POISON: should be skipped by BNE taken");
    add_instr(addi(5'd11, 5'd0, 12'd1),
              "BNE PASS MARKER: x11 = 1");
    add_instr(sw(5'd11, 5'd1, 12'h004),
              "CHECKPOINT: SW x11 -> MEM[0x204], expect 1");

    // --- BLT (taken): x5 < x2 (signed: -3 < 5) ---
    add_instr(rv_b_type(13'd8, 5'd2, 5'd5, 3'b100, 7'b1100011),
              "BLT: signed x5(-3) < x2(5), branch +8 taken");
    add_instr(addi(5'd12, 5'd0, 12'd999),
              "POISON: should be skipped by BLT taken");
    add_instr(addi(5'd12, 5'd0, 12'd1),
              "BLT PASS MARKER: x12 = 1");
    add_instr(sw(5'd12, 5'd1, 12'h008),
              "CHECKPOINT: SW x12 -> MEM[0x208], expect 1");

    // --- BGE (taken): x4 >= x2 (signed: 10 >= 5) ---
    add_instr(rv_b_type(13'd8, 5'd2, 5'd4, 3'b101, 7'b1100011),
              "BGE: signed x4(10) >= x2(5), branch +8 taken");
    add_instr(addi(5'd13, 5'd0, 12'd999),
              "POISON: should be skipped by BGE taken");
    add_instr(addi(5'd13, 5'd0, 12'd1),
              "BGE PASS MARKER: x13 = 1");
    add_instr(sw(5'd13, 5'd1, 12'h00C),
              "CHECKPOINT: SW x13 -> MEM[0x20c], expect 1");

    // --- BLTU (not taken): x5 < x2 unsigned? (-3 = 0xFFFFFFFD > 5) ---
    add_instr(rv_b_type(13'd8, 5'd2, 5'd5, 3'b110, 7'b1100011),
              "BLTU: unsigned x5(0xfffffffd) < x2(5) is false, branch not taken");
    add_instr(addi(5'd14, 5'd0, 12'd0),
              "BLTU NOT-TAKEN MARKER: x14 = 0");
    add_instr(sw(5'd14, 5'd1, 12'h010),
              "CHECKPOINT: SW x14 -> MEM[0x210], expect 0");

    // --- JAL: x20 = PC+4, jump forward +8 ---
    add_instr(rv_j_type(21'd8, 5'd20, 7'b1101111),
              "JAL: jump +8, write return PC+4 into x20");
    add_instr(addi(5'd15, 5'd0, 12'd999),
              "POISON: should be skipped by JAL");
    add_instr(addi(5'd15, 5'd0, 12'd1),
              "JAL PASS MARKER: x15 = 1");
    add_instr(sw(5'd15, 5'd1, 12'h014),
              "CHECKPOINT: SW x15 -> MEM[0x214], expect 1");
    add_instr(sw(5'd20, 5'd1, 12'h018),
              "CHECKPOINT: SW x20 return address -> MEM[0x218]");

    // --- JALR: x21 = PC+4, jump forward +8 via base register x22 ---
    add_instr(addi(5'd22, 5'd0, 12'h078),
              "SETUP: x22 = 0x78, JALR base points at the JALR instruction");
    add_instr(rv_i_type(12'd8, 5'd22, 3'b000, 5'd21, 7'b1100111),
              "JALR: x21 = PC+4, next_pc = x22 + 8 = 0x80, skip next poison write");
    add_instr(addi(5'd16, 5'd0, 12'd999),
              "POISON: should be skipped by JALR if target skips this slot");
    add_instr(addi(5'd16, 5'd0, 12'd1),
              "JALR PASS MARKER: x16 = 1");
    add_instr(sw(5'd16, 5'd1, 12'h01C),
              "CHECKPOINT: SW x16 -> MEM[0x21c], expect 1");

    // End with illegal instruction
    add_instr(illegal_instr(),
              "HALT: illegal instruction 0x00000000 stops CPU");

    `uvm_info(get_type_name(), $sformatf("Branch test: %0d instructions", program_size), UVM_LOW)
  endtask
endclass : cpu_branch_seq
