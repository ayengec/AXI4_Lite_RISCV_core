// cpu_branch_corner_seq.sv
// Author: Alican Yengec
// Purpose: Targeted branch corner coverage for unsigned branch directions.

class cpu_branch_corner_seq extends cpu_base_seq;
  `uvm_object_utils(cpu_branch_corner_seq)

  function new(string name = "cpu_branch_corner_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Building branch corner program", UVM_LOW)
    clear_program();

    add_instr(addi(5'd1, 5'd0, 12'h200),
              "SETUP: ADDI x1 = x0 + 0x200 -> data base 0x00000200");
    add_instr(addi(5'd2, 5'd0, 12'd5),
              "SETUP: ADDI x2 = 5");
    add_instr(addi(5'd3, 5'd0, 12'd10),
              "SETUP: ADDI x3 = 10");
    add_instr(addi(5'd4, 5'd0, -12'sd1),
              "SETUP: ADDI x4 = -1 -> 0xffffffff");

    add_instr(rv_b_type(13'd8, 5'd3, 5'd2, 3'b110, 7'b1100011),
              "BLTU: unsigned x2(5) < x3(10), branch +8 taken");
    add_instr(addi(5'd10, 5'd0, 12'd999),
              "POISON: should be skipped by BLTU taken");
    add_instr(addi(5'd10, 5'd0, 12'd1),
              "BLTU TAKEN MARKER: x10 = 1");
    add_instr(sw(5'd10, 5'd1, 12'h000),
              "CHECKPOINT: SW x10 -> MEM[0x200], expect 1");

    add_instr(rv_b_type(13'd8, 5'd3, 5'd4, 3'b111, 7'b1100011),
              "BGEU: unsigned x4(0xffffffff) >= x3(10), branch +8 taken");
    add_instr(addi(5'd11, 5'd0, 12'd999),
              "POISON: should be skipped by BGEU taken");
    add_instr(addi(5'd11, 5'd0, 12'd1),
              "BGEU TAKEN MARKER: x11 = 1");
    add_instr(sw(5'd11, 5'd1, 12'h004),
              "CHECKPOINT: SW x11 -> MEM[0x204], expect 1");

    add_instr(addi(5'd12, 5'd0, 12'd2),
              "SETUP: x12 = 2 before BGEU not-taken check");
    add_instr(rv_b_type(13'd8, 5'd3, 5'd2, 3'b111, 7'b1100011),
              "BGEU: unsigned x2(5) >= x3(10) is false, branch not taken");
    add_instr(addi(5'd12, 5'd0, 12'd0),
              "BGEU NOT-TAKEN MARKER: x12 = 0");
    add_instr(sw(5'd12, 5'd1, 12'h008),
              "CHECKPOINT: SW x12 -> MEM[0x208], expect 0");

    add_instr(illegal_instr(),
              "HALT: illegal instruction 0x00000000 stops CPU");

    `uvm_info(get_type_name(), $sformatf("Branch corner program: %0d instructions", program_size), UVM_LOW)
  endtask
endclass : cpu_branch_corner_seq
