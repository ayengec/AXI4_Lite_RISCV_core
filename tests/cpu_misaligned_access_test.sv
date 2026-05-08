// cpu_misaligned_access_test.sv
// Author: Alican Yengec
// Purpose: Directed misaligned load/store halt tests.

class cpu_misaligned_access_test extends cpu_base_test;
  `uvm_component_utils(cpu_misaligned_access_test)

  function new(string name = "cpu_misaligned_access_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_halt_case(string label, cpu_base_seq seq);
    `uvm_info(get_type_name(), $sformatf("Starting misaligned access case: %s", label), UVM_LOW)
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
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'h200), "SETUP: x1 = data base 0x200");
    seq.add_instr(seq.rv_i_type(12'h001, 5'd1, 3'b010, 5'd2, 7'b0000011),
                  "MISALIGNED LW: x2 = MEM[0x201], expect halt");
    seq.add_instr(seq.addi(5'd3, 5'd0, 12'd99), "POISON: should not execute after misaligned LW");
    run_halt_case("misaligned LW", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'h200), "SETUP: x1 = data base 0x200");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd42), "SETUP: x2 = 42");
    seq.add_instr(seq.rv_s_type(12'h001, 5'd2, 5'd1, 3'b010, 7'b0100011),
                  "MISALIGNED SW: MEM[0x201] = x2, expect halt");
    seq.add_instr(seq.addi(5'd3, 5'd0, 12'd99), "POISON: should not execute after misaligned SW");
    run_halt_case("misaligned SW", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'h200), "SETUP: x1 = data base 0x200");
    seq.add_instr(seq.rv_i_type(12'h001, 5'd1, 3'b001, 5'd2, 7'b0000011),
                  "MISALIGNED LH: x2 = MEM[0x201], expect halt");
    seq.add_instr(seq.addi(5'd3, 5'd0, 12'd99), "POISON: should not execute after misaligned LH");
    run_halt_case("misaligned LH", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'h200), "SETUP: x1 = data base 0x200");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd42), "SETUP: x2 = 42");
    seq.add_instr(seq.rv_s_type(12'h001, 5'd2, 5'd1, 3'b001, 7'b0100011),
                  "MISALIGNED SH: MEM[0x201] = x2[15:0], expect halt");
    seq.add_instr(seq.addi(5'd3, 5'd0, 12'd99), "POISON: should not execute after misaligned SH");
    run_halt_case("misaligned SH", seq);

    `uvm_info(get_type_name(), "=== TEST PASSED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass : cpu_misaligned_access_test
