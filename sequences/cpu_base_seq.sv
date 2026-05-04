// cpu_base_seq.sv
// Author: Alican Yengec
// Base program sequence for CPU testbench.
// Provides common instruction encoding helpers and program storage.

class cpu_base_seq extends uvm_sequence;
  `uvm_object_utils(cpu_base_seq)

  cpu_env       env_h;
  cpu_ref_model ref_model;

  // Program storage
  logic [31:0] program_mem[];
  string       program_desc[];
  int          program_size;

  function new(string name = "cpu_base_seq");
    super.new(name);
    program_size = 0;
  endfunction

  // Helper: encode R-type instruction
  function logic [31:0] rv_r_type(logic [6:0] funct7, logic [4:0] rs2, logic [4:0] rs1, logic [2:0] funct3, logic [4:0] rd, logic [6:0] opcode);
    return {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  // Helper: encode I-type instruction
  function logic [31:0] rv_i_type(logic [11:0] imm, logic [4:0] rs1, logic [2:0] funct3, logic [4:0] rd, logic [6:0] opcode);
    return {imm, rs1, funct3, rd, opcode};
  endfunction

  // Helper: encode S-type instruction
  function logic [31:0] rv_s_type(logic [11:0] imm, logic [4:0] rs2, logic [4:0] rs1, logic [2:0] funct3, logic [6:0] opcode);
    return {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
  endfunction

  // Helper: encode B-type instruction
  function logic [31:0] rv_b_type(logic [12:0] imm, logic [4:0] rs2, logic [4:0] rs1, logic [2:0] funct3, logic [6:0] opcode);
    return {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
  endfunction

  // Helper: encode U-type instruction
  function logic [31:0] rv_u_type(logic [31:0] imm, logic [4:0] rd, logic [6:0] opcode);
    return {imm[31:12], rd, opcode};
  endfunction

  // Helper: encode J-type instruction
  function logic [31:0] rv_j_type(logic [20:0] imm, logic [4:0] rd, logic [6:0] opcode);
    return {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
  endfunction

  // Common instruction encodings
  function logic [31:0] addi(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
    return rv_i_type(imm, rs1, 3'b000, rd, 7'b0010011);
  endfunction

  function logic [31:0] add(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
    return rv_r_type(7'b0000000, rs2, rs1, 3'b000, rd, 7'b0110011);
  endfunction

  function logic [31:0] sub(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
    return rv_r_type(7'b0100000, rs2, rs1, 3'b000, rd, 7'b0110011);
  endfunction

  function logic [31:0] sw(logic [4:0] rs2, logic [4:0] rs1, logic [11:0] imm);
    return rv_s_type(imm, rs2, rs1, 3'b010, 7'b0100011);
  endfunction

  function logic [31:0] lw(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
    return rv_i_type(imm, rs1, 3'b010, rd, 7'b0000011);
  endfunction

  function logic [31:0] lui(logic [4:0] rd, logic [19:0] imm);
    return {imm, rd, 7'b0110111};
  endfunction

  function logic [31:0] nop();
    return addi(5'd0, 5'd0, 12'd0);
  endfunction

  function logic [31:0] illegal_instr();
    return 32'h00000000;  // all zeros = illegal
  endfunction

  function string disasm(logic [31:0] instr);
    logic [6:0] opcode;
    logic [4:0] rd, rs1, rs2;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [31:0] imm_i, imm_s, imm_u;

    opcode = instr[6:0];
    rd     = instr[11:7];
    funct3 = instr[14:12];
    rs1    = instr[19:15];
    rs2    = instr[24:20];
    funct7 = instr[31:25];
    imm_i  = {{20{instr[31]}}, instr[31:20]};
    imm_s  = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    imm_u  = {instr[31:12], 12'h0};

    case (opcode)
      7'b0110111: return $sformatf("LUI x%0d, 0x%05h", rd, instr[31:12]);
      7'b0010111: return $sformatf("AUIPC x%0d, 0x%05h", rd, instr[31:12]);
      7'b0010011: begin
        case (funct3)
          3'b000: return $sformatf("ADDI x%0d, x%0d, %0d", rd, rs1, $signed(imm_i));
          3'b100: return $sformatf("XORI x%0d, x%0d, 0x%03h", rd, rs1, instr[31:20]);
          3'b110: return $sformatf("ORI x%0d, x%0d, 0x%03h", rd, rs1, instr[31:20]);
          3'b111: return $sformatf("ANDI x%0d, x%0d, 0x%03h", rd, rs1, instr[31:20]);
          3'b001: return $sformatf("SLLI x%0d, x%0d, %0d", rd, rs1, instr[24:20]);
          3'b101: return funct7[5]
            ? $sformatf("SRAI x%0d, x%0d, %0d", rd, rs1, instr[24:20])
            : $sformatf("SRLI x%0d, x%0d, %0d", rd, rs1, instr[24:20]);
          default: return $sformatf("OP-IMM funct3=%0b", funct3);
        endcase
      end
      7'b0110011: begin
        case ({funct7, funct3})
          {7'b0000000, 3'b000}: return $sformatf("ADD x%0d, x%0d, x%0d", rd, rs1, rs2);
          {7'b0100000, 3'b000}: return $sformatf("SUB x%0d, x%0d, x%0d", rd, rs1, rs2);
          {7'b0000000, 3'b111}: return $sformatf("AND x%0d, x%0d, x%0d", rd, rs1, rs2);
          {7'b0000000, 3'b110}: return $sformatf("OR x%0d, x%0d, x%0d", rd, rs1, rs2);
          {7'b0000000, 3'b100}: return $sformatf("XOR x%0d, x%0d, x%0d", rd, rs1, rs2);
          {7'b0000000, 3'b001}: return $sformatf("SLL x%0d, x%0d, x%0d", rd, rs1, rs2);
          {7'b0000000, 3'b101}: return $sformatf("SRL x%0d, x%0d, x%0d", rd, rs1, rs2);
          {7'b0100000, 3'b101}: return $sformatf("SRA x%0d, x%0d, x%0d", rd, rs1, rs2);
          {7'b0000000, 3'b010}: return $sformatf("SLT x%0d, x%0d, x%0d", rd, rs1, rs2);
          {7'b0000000, 3'b011}: return $sformatf("SLTU x%0d, x%0d, x%0d", rd, rs1, rs2);
          default: return $sformatf("OP funct7=0x%02h funct3=%0b", funct7, funct3);
        endcase
      end
      7'b0100011: begin
        case (funct3)
          3'b010: return $sformatf("SW x%0d, %0d(x%0d)", rs2, $signed(imm_s), rs1);
          3'b001: return $sformatf("SH x%0d, %0d(x%0d)", rs2, $signed(imm_s), rs1);
          3'b000: return $sformatf("SB x%0d, %0d(x%0d)", rs2, $signed(imm_s), rs1);
          default: return $sformatf("STORE funct3=%0b", funct3);
        endcase
      end
      7'b0000011: return $sformatf("LOAD x%0d, %0d(x%0d)", rd, $signed(imm_i), rs1);
      7'b1100011: return $sformatf("BRANCH funct3=%0b x%0d, x%0d", funct3, rs1, rs2);
      7'b1101111: return $sformatf("JAL x%0d", rd);
      7'b1100111: return $sformatf("JALR x%0d, %0d(x%0d)", rd, $signed(imm_i), rs1);
      default: return (instr == 32'h0) ? "ILLEGAL/HALT" : $sformatf("UNKNOWN 0x%08h", instr);
    endcase
  endfunction

  // Add instruction to program
  function void add_instr(logic [31:0] instr, string desc = "");
    program_mem = new[program_size + 1](program_mem);
    program_desc = new[program_size + 1](program_desc);
    program_mem[program_size] = instr;
    program_desc[program_size] = (desc == "") ? disasm(instr) : desc;
    program_size++;
  endfunction

  // Clear program
  function void clear_program();
    program_mem = new[0];
    program_desc = new[0];
    program_size = 0;
  endfunction

  function void print_program();
    `uvm_info(get_type_name(), $sformatf("Program listing (%0d instructions)", program_size), UVM_LOW)
    for (int i = 0; i < program_size; i++) begin
      `uvm_info(get_type_name(), $sformatf(
        "PROGRAM STEP %03d PC=0x%08h INSTR=0x%08h  %s",
        i, i * 4, program_mem[i], program_desc[i]), UVM_LOW)
    end
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Base virtual sequence - override in subclass", UVM_LOW)
  endtask
endclass : cpu_base_seq
