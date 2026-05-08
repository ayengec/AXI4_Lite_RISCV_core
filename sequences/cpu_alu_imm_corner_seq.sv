// cpu_alu_imm_corner_seq.sv
// Author: Alican Yengec
// Purpose: Targeted immediate-ALU corner coverage for SLTI and SLTIU.

class cpu_alu_imm_corner_seq extends cpu_base_seq;
  `uvm_object_utils(cpu_alu_imm_corner_seq)

  function new(string name = "cpu_alu_imm_corner_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Building ALU immediate corner program", UVM_LOW)
    clear_program();

    add_instr(addi(5'd1, 5'd0, 12'h200),
              "SETUP: ADDI x1 = x0 + 0x200 -> data base 0x00000200");
    add_instr(addi(5'd2, 5'd0, 12'd5),
              "SETUP: ADDI x2 = 5");
    add_instr(addi(5'd3, 5'd0, -12'sd5),
              "SETUP: ADDI x3 = -5 -> 0xfffffffb");
    add_instr(addi(5'd4, 5'd0, 12'd1),
              "SETUP: ADDI x4 = 1");

    add_instr(rv_i_type(12'd0, 5'd3, 3'b010, 5'd10, 7'b0010011),
              "SLTI: x10 = signed(x3=-5) < 0 -> 1");
    add_instr(sw(5'd10, 5'd1, 12'h000),
              "CHECKPOINT: SW x10 -> MEM[0x200], expect 0x00000001");

    add_instr(rv_i_type(12'd0, 5'd2, 3'b010, 5'd11, 7'b0010011),
              "SLTI: x11 = signed(x2=5) < 0 -> 0");
    add_instr(sw(5'd11, 5'd1, 12'h004),
              "CHECKPOINT: SW x11 -> MEM[0x204], expect 0x00000000");

    add_instr(rv_i_type(-12'sd1, 5'd4, 3'b011, 5'd12, 7'b0010011),
              "SLTIU: x12 = unsigned(x4=1) < signext(-1)=0xffffffff -> 1");
    add_instr(sw(5'd12, 5'd1, 12'h008),
              "CHECKPOINT: SW x12 -> MEM[0x208], expect 0x00000001");

    add_instr(rv_i_type(12'd1, 5'd3, 3'b011, 5'd13, 7'b0010011),
              "SLTIU: x13 = unsigned(x3=0xfffffffb) < 1 -> 0");
    add_instr(sw(5'd13, 5'd1, 12'h00c),
              "CHECKPOINT: SW x13 -> MEM[0x20c], expect 0x00000000");

    add_instr(illegal_instr(),
              "HALT: illegal instruction 0x00000000 stops CPU");

    `uvm_info(get_type_name(), $sformatf("ALU immediate corner program: %0d instructions", program_size), UVM_LOW)
  endtask
endclass : cpu_alu_imm_corner_seq
