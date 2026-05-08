// cpu_regfile_semantics_seq.sv
// Author: Alican Yengec
// Purpose: Directed register-file semantics checks for x0 and dependent reads.

class cpu_regfile_semantics_seq extends cpu_base_seq;
  `uvm_object_utils(cpu_regfile_semantics_seq)

  function new(string name = "cpu_regfile_semantics_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Building register-file semantics program", UVM_LOW)
    clear_program();

    add_instr(addi(5'd1, 5'd0, 12'h200),
              "SETUP: ADDI x1 = x0 + 0x200 -> data base 0x00000200");

    add_instr(addi(5'd0, 5'd0, 12'd123),
              "X0 DISCARD: ADDI x0 = x0 + 123, expect x0 remains zero");
    add_instr(sw(5'd0, 5'd1, 12'h000),
              "CHECKPOINT: SW x0 -> MEM[0x200], expect 0x00000000");

    add_instr(addi(5'd2, 5'd0, 12'd5),
              "SETUP: x2 = 5");
    add_instr(addi(5'd3, 5'd0, 12'd6),
              "SETUP: x3 = 6");
    add_instr(add(5'd4, 5'd2, 5'd3),
              "DEPENDENCY: ADD x4 = x2 + x3 -> 11");
    add_instr(add(5'd5, 5'd4, 5'd3),
              "DEPENDENCY: ADD x5 = freshly-written x4 + x3 -> 17");
    add_instr(add(5'd5, 5'd5, 5'd2),
              "SAME-REG DEPENDENCY: ADD x5 = x5 + x2 -> 22");
    add_instr(sw(5'd5, 5'd1, 12'h004),
              "CHECKPOINT: SW x5 -> MEM[0x204], expect 0x00000016");

    add_instr(lw(5'd0, 5'd1, 12'h004),
              "X0 DISCARD: LW x0, MEM[0x204], expect x0 remains zero");
    add_instr(sw(5'd0, 5'd1, 12'h008),
              "CHECKPOINT: SW x0 -> MEM[0x208], expect 0x00000000");

    add_instr(illegal_instr(),
              "HALT: illegal instruction 0x00000000 stops CPU");

    `uvm_info(get_type_name(), $sformatf("Register-file semantics program: %0d instructions", program_size), UVM_LOW)
  endtask
endclass : cpu_regfile_semantics_seq
