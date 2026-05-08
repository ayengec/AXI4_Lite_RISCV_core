// cpu_jump_x0_seq.sv
// Author: Alican Yengec
// Purpose: Targeted JAL/JALR rd=x0 coverage.

class cpu_jump_x0_seq extends cpu_base_seq;
  `uvm_object_utils(cpu_jump_x0_seq)

  function new(string name = "cpu_jump_x0_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Building jump rd=x0 program", UVM_LOW)
    clear_program();

    add_instr(addi(5'd1, 5'd0, 12'h200),
              "SETUP: ADDI x1 = x0 + 0x200 -> data base 0x00000200");

    add_instr(rv_j_type(21'd8, 5'd0, 7'b1101111),
              "JAL x0: jump +8, discard return address, skip poison write");
    add_instr(addi(5'd10, 5'd0, 12'd999),
              "POISON: should be skipped by JAL x0");
    add_instr(addi(5'd10, 5'd0, 12'd1),
              "JAL x0 PASS MARKER: x10 = 1");
    add_instr(sw(5'd10, 5'd1, 12'h000),
              "CHECKPOINT: SW x10 -> MEM[0x200], expect 1");

    add_instr(addi(5'd22, 5'd0, 12'h018),
              "SETUP: x22 = 0x18, JALR base points at the JALR instruction");
    add_instr(rv_i_type(12'd8, 5'd22, 3'b000, 5'd0, 7'b1100111),
              "JALR x0: next_pc = x22 + 8 = 0x20, discard return address, skip poison write");
    add_instr(addi(5'd11, 5'd0, 12'd999),
              "POISON: should be skipped by JALR x0");
    add_instr(addi(5'd11, 5'd0, 12'd1),
              "JALR x0 PASS MARKER: x11 = 1");
    add_instr(sw(5'd11, 5'd1, 12'h004),
              "CHECKPOINT: SW x11 -> MEM[0x204], expect 1");
    add_instr(sw(5'd0, 5'd1, 12'h008),
              "CHECKPOINT: SW x0 -> MEM[0x208], expect 0 after JAL/JALR rd=x0");

    add_instr(illegal_instr(),
              "HALT: illegal instruction 0x00000000 stops CPU");

    `uvm_info(get_type_name(), $sformatf("Jump rd=x0 program: %0d instructions", program_size), UVM_LOW)
  endtask
endclass : cpu_jump_x0_seq
