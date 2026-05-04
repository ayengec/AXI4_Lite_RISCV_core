// cpu_coverage.sv
// Author: Alican Yengec
// Collects functional coverage on RV32I instructions executed by the CPU.

class cpu_coverage extends uvm_subscriber #(logic [31:0]);
  `uvm_component_utils(cpu_coverage)

  // Instruction fields extracted for coverage
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [4:0] rd;
  logic [4:0] rs1;
  logic [4:0] rs2;

  // RV32I Base Instruction Set Covergroup
  covergroup cg_rv32i;
    option.per_instance = 1;
    option.name = "RV32I_Base_Coverage";

    // 1. Cover all major instruction types
    cp_opcode: coverpoint opcode {
      bins load   = {7'b0000011}; // LW, LH, LB, LHU, LBU
      bins store  = {7'b0100011}; // SW, SH, SB
      bins branch = {7'b1100011}; // BEQ, BNE, BLT, BGE, BLTU, BGEU
      bins jalr   = {7'b1100111}; // JALR
      bins jal    = {7'b1101111}; // JAL
      bins op_imm = {7'b0010011}; // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
      bins op     = {7'b0110011}; // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
      bins lui    = {7'b0110111}; // LUI
      bins auipc  = {7'b0010111}; // AUIPC
      bins system = {7'b1110011}; // ECALL, EBREAK
      bins misc   = {7'b0001111}; // FENCE
    }

    // 2. Cover register usage
    // Ensuring all 32 registers are used as destinations
    cp_rd: coverpoint rd {
      bins all_regs[] = {[0:31]};
    }

    // Ensuring all 32 registers are used as source 1
    cp_rs1: coverpoint rs1 {
      bins all_regs[] = {[0:31]};
    }

    // Ensuring all 32 registers are used as source 2
    cp_rs2: coverpoint rs2 {
      bins all_regs[] = {[0:31]};
    }

    // 3. Detailed Operation Coverage (Crosses)
    // Cross opcode with funct3 to ensure all sub-types are hit
    cross_op_imm_funct3: cross cp_opcode, funct3 {
      ignore_bins ignore_others = binsof(cp_opcode) intersect {
        7'b0000011, 7'b0100011, 7'b1100011, 7'b1100111, 7'b1101111, 7'b0110011, 7'b0110111, 7'b0010111, 7'b1110011, 7'b0001111
      };
    }

    cross_op_funct3: cross cp_opcode, funct3 {
      ignore_bins ignore_others = binsof(cp_opcode) intersect {
        7'b0000011, 7'b0100011, 7'b1100011, 7'b1100111, 7'b1101111, 7'b0010011, 7'b0110111, 7'b0010111, 7'b1110011, 7'b0001111
      };
    }

    cross_load_funct3: cross cp_opcode, funct3 {
      ignore_bins ignore_others = binsof(cp_opcode) intersect {
        7'b0100011, 7'b1100011, 7'b1100111, 7'b1101111, 7'b0010011, 7'b0110011, 7'b0110111, 7'b0010111, 7'b1110011, 7'b0001111
      };
      // RV32I only uses funct3 0, 1, 2, 4, 5 for loads
      ignore_bins ignore_invalid_loads = binsof(funct3) intersect {3, 6, 7};
    }

    cross_store_funct3: cross cp_opcode, funct3 {
      ignore_bins ignore_others = binsof(cp_opcode) intersect {
        7'b0000011, 7'b1100011, 7'b1100111, 7'b1101111, 7'b0010011, 7'b0110011, 7'b0110111, 7'b0010111, 7'b1110011, 7'b0001111
      };
      // RV32I only uses funct3 0, 1, 2 for stores
      ignore_bins ignore_invalid_stores = binsof(funct3) intersect {3, 4, 5, 6, 7};
    }

    cross_branch_funct3: cross cp_opcode, funct3 {
      ignore_bins ignore_others = binsof(cp_opcode) intersect {
        7'b0000011, 7'b0100011, 7'b1100111, 7'b1101111, 7'b0010011, 7'b0110011, 7'b0110111, 7'b0010111, 7'b1110011, 7'b0001111
      };
      // RV32I does not use funct3 2, 3 for branches
      ignore_bins ignore_invalid_branches = binsof(funct3) intersect {2, 3};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_rv32i = new();
  endfunction

  // Called via Analysis Port from ref_model
  virtual function void write(logic [31:0] t);
    // Decode instruction fields
    opcode = t[6:0];
    rd     = t[11:7];
    funct3 = t[14:12];
    rs1    = t[19:15];
    rs2    = t[24:20];
    funct7 = t[31:25];

    // Sample coverage
    cg_rv32i.sample();
  endfunction

endclass : cpu_coverage
