// cpu_invalid_decode_test.sv
// Author: Alican Yengec
// Purpose: Directed invalid decode halt tests for opcode sub-fields.

class cpu_invalid_decode_test extends cpu_base_test;
  `uvm_component_utils(cpu_invalid_decode_test)

  function new(string name = "cpu_invalid_decode_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_halt_case(string label, cpu_base_seq seq);
    `uvm_info(get_type_name(), $sformatf("Starting invalid decode case: %s", label), UVM_LOW)
    preload_and_start_no_ref(seq);
    wait_cpu_halt();
    if (!vif.illegal_instr())
      `uvm_error(get_type_name(), $sformatf("FAIL: %s did not assert illegal_instr", label))
    else
      `uvm_info(get_type_name(), $sformatf("PASS: %s halted on illegal_instr", label), UVM_LOW)
  endtask

  task run_phase(uvm_phase phase);
    cpu_base_seq seq = cpu_base_seq::type_id::create("seq");
    phase.raise_objection(this);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd0), "SETUP: x1 = 0");
    seq.add_instr(seq.rv_i_type(12'd0, 5'd1, 3'b001, 5'd2, 7'b1100111),
                  "INVALID JALR: funct3 != 000, expect halt");
    run_halt_case("invalid JALR funct3", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd1), "SETUP: x1 = 1");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd2), "SETUP: x2 = 2");
    seq.add_instr(seq.rv_b_type(13'd8, 5'd2, 5'd1, 3'b010, 7'b1100011),
                  "INVALID BRANCH: funct3=010, expect halt");
    run_halt_case("invalid branch funct3", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'h200), "SETUP: x1 = data base");
    seq.add_instr(seq.rv_i_type(12'd0, 5'd1, 3'b011, 5'd2, 7'b0000011),
                  "INVALID LOAD: funct3=011, expect halt");
    run_halt_case("invalid load funct3", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'h200), "SETUP: x1 = data base");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd7), "SETUP: x2 = 7");
    seq.add_instr(seq.rv_s_type(12'd0, 5'd2, 5'd1, 3'b011, 7'b0100011),
                  "INVALID STORE: funct3=011, expect halt");
    run_halt_case("invalid store funct3", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd1), "SETUP: x1 = 1");
    seq.add_instr(seq.rv_i_type({7'b0000001, 5'd1}, 5'd1, 3'b001, 5'd2, 7'b0010011),
                  "INVALID OP-IMM: SLLI with funct7 != 0000000, expect halt");
    run_halt_case("invalid OP-IMM SLLI funct7", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd1), "SETUP: x1 = 1");
    seq.add_instr(seq.rv_i_type({7'b0000001, 5'd1}, 5'd1, 3'b101, 5'd2, 7'b0010011),
                  "INVALID OP-IMM: SRLI/SRAI with illegal funct7, expect halt");
    run_halt_case("invalid OP-IMM SRLI/SRAI funct7", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd1), "SETUP: x1 = 1");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd2), "SETUP: x2 = 2");
    seq.add_instr(seq.rv_r_type(7'b0000001, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011),
                  "INVALID OP: ADD/SUB slot with illegal funct7, expect halt");
    run_halt_case("invalid OP ADD/SUB funct7", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd1), "SETUP: x1 = 1");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd2), "SETUP: x2 = 2");
    seq.add_instr(seq.rv_r_type(7'b0000001, 5'd2, 5'd1, 3'b001, 5'd3, 7'b0110011),
                  "INVALID OP: SLL with funct7 != 0000000, expect halt");
    run_halt_case("invalid OP SLL funct7", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd1), "SETUP: x1 = 1");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd2), "SETUP: x2 = 2");
    seq.add_instr(seq.rv_r_type(7'b0000001, 5'd2, 5'd1, 3'b010, 5'd3, 7'b0110011),
                  "INVALID OP: SLT with funct7 != 0000000, expect halt");
    run_halt_case("invalid OP SLT funct7", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd1), "SETUP: x1 = 1");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd2), "SETUP: x2 = 2");
    seq.add_instr(seq.rv_r_type(7'b0000001, 5'd2, 5'd1, 3'b011, 5'd3, 7'b0110011),
                  "INVALID OP: SLTU with funct7 != 0000000, expect halt");
    run_halt_case("invalid OP SLTU funct7", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd1), "SETUP: x1 = 1");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd2), "SETUP: x2 = 2");
    seq.add_instr(seq.rv_r_type(7'b0000001, 5'd2, 5'd1, 3'b100, 5'd3, 7'b0110011),
                  "INVALID OP: XOR with funct7 != 0000000, expect halt");
    run_halt_case("invalid OP XOR funct7", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd1), "SETUP: x1 = 1");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd2), "SETUP: x2 = 2");
    seq.add_instr(seq.rv_r_type(7'b0000001, 5'd2, 5'd1, 3'b101, 5'd3, 7'b0110011),
                  "INVALID OP: SRL/SRA slot with illegal funct7, expect halt");
    run_halt_case("invalid OP SRL/SRA funct7", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd1), "SETUP: x1 = 1");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd2), "SETUP: x2 = 2");
    seq.add_instr(seq.rv_r_type(7'b0000001, 5'd2, 5'd1, 3'b110, 5'd3, 7'b0110011),
                  "INVALID OP: OR with funct7 != 0000000, expect halt");
    run_halt_case("invalid OP funct7", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd1), "SETUP: x1 = 1");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd2), "SETUP: x2 = 2");
    seq.add_instr(seq.rv_r_type(7'b0000001, 5'd2, 5'd1, 3'b111, 5'd3, 7'b0110011),
                  "INVALID OP: AND with funct7 != 0000000, expect halt");
    run_halt_case("invalid OP AND funct7", seq);

    `uvm_info(get_type_name(), "=== TEST PASSED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass : cpu_invalid_decode_test
