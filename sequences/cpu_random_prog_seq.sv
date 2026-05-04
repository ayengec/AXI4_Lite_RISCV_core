// cpu_random_prog_seq.sv
// Author: Alican Yengec
// Generates constrained-random RV32I programs.
// The reference model executes the same program to produce expected results.

class cpu_random_prog_seq extends cpu_base_seq;
  `uvm_object_utils(cpu_random_prog_seq)

  rand int num_alu_instrs;
  rand int num_mem_instrs;

  constraint size_c {
    num_alu_instrs inside {[5:20]};
    num_mem_instrs inside {[2:8]};
  }

  function new(string name = "cpu_random_prog_seq");
    super.new(name);
  endfunction

  virtual task body();
    int total;
    `uvm_info(get_type_name(), "Generating random RV32I program", UVM_LOW)
    clear_program();

    // Setup: x1 = 0x200 (data memory base)
    add_instr(addi(5'd1, 5'd0, 12'h200),
              "SETUP: ADDI x1 = x0 + 0x200 -> data base 0x00000200");

    // Generate random ALU instructions
    for (int i = 0; i < num_alu_instrs; i++) begin
      logic [31:0] instr;
      int op_type;
      logic [4:0] rd, rs1, rs2;
      logic [11:0] imm12;
      string desc;

      // Don't write to x0 or x1 (preserve data base pointer)
      rd  = $urandom_range(2, 31);
      rs1 = $urandom_range(0, 31);
      rs2 = $urandom_range(0, 31);
      imm12 = $urandom_range(0, 4095);
      op_type = $urandom_range(0, 9);

      case (op_type)
        0: begin instr = addi(rd, rs1, imm12); desc = $sformatf("RANDOM ALU: ADDI x%0d = x%0d + %0d", rd, rs1, $signed({{20{imm12[11]}}, imm12})); end
        1: begin instr = rv_i_type(imm12, rs1, 3'b100, rd, 7'b0010011); desc = $sformatf("RANDOM ALU: XORI x%0d = x%0d ^ 0x%03h", rd, rs1, imm12); end
        2: begin instr = rv_i_type(imm12, rs1, 3'b110, rd, 7'b0010011); desc = $sformatf("RANDOM ALU: ORI x%0d = x%0d | 0x%03h", rd, rs1, imm12); end
        3: begin instr = rv_i_type(imm12, rs1, 3'b111, rd, 7'b0010011); desc = $sformatf("RANDOM ALU: ANDI x%0d = x%0d & 0x%03h", rd, rs1, imm12); end
        4: begin instr = rv_i_type({7'b0000000, imm12[4:0]}, rs1, 3'b001, rd, 7'b0010011); desc = $sformatf("RANDOM ALU: SLLI x%0d = x%0d << %0d", rd, rs1, imm12[4:0]); end
        5: begin instr = rv_i_type({7'b0000000, imm12[4:0]}, rs1, 3'b101, rd, 7'b0010011); desc = $sformatf("RANDOM ALU: SRLI x%0d = x%0d >> %0d", rd, rs1, imm12[4:0]); end
        6: begin instr = add(rd, rs1, rs2); desc = $sformatf("RANDOM ALU: ADD x%0d = x%0d + x%0d", rd, rs1, rs2); end
        7: begin instr = sub(rd, rs1, rs2); desc = $sformatf("RANDOM ALU: SUB x%0d = x%0d - x%0d", rd, rs1, rs2); end
        8: begin instr = rv_r_type(7'b0000000, rs2, rs1, 3'b100, rd, 7'b0110011); desc = $sformatf("RANDOM ALU: XOR x%0d = x%0d ^ x%0d", rd, rs1, rs2); end
        9: begin instr = rv_r_type(7'b0000000, rs2, rs1, 3'b110, rd, 7'b0110011); desc = $sformatf("RANDOM ALU: OR x%0d = x%0d | x%0d", rd, rs1, rs2); end
      endcase

      add_instr(instr, desc);
    end

    // Store some register values to data memory for checking
    for (int i = 0; i < num_mem_instrs && i < 16; i++) begin
      logic [4:0] rs = $urandom_range(2, 31);
      add_instr(sw(rs, 5'd1, i * 4), $sformatf(
        "RANDOM CHECKPOINT: SW x%0d -> MEM[0x%03h]", rs, 32'h200 + (i * 4)));
    end

    // End with illegal instruction
    add_instr(illegal_instr(),
              "HALT: illegal instruction 0x00000000 stops CPU");

    total = program_size;
    `uvm_info(get_type_name(), $sformatf("Random program: %0d instructions (%0d ALU + %0d stores)", total, num_alu_instrs, num_mem_instrs), UVM_LOW)
  endtask
endclass : cpu_random_prog_seq
