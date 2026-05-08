// cpu_misaligned_control_test.sv
// Author: Alican Yengec
// Purpose: Directed misaligned branch/jump target halt tests.

class cpu_misaligned_control_test extends cpu_base_test;
  `uvm_component_utils(cpu_misaligned_control_test)

  function new(string name = "cpu_misaligned_control_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_halt_case(string label, cpu_base_seq seq);
    `uvm_info(get_type_name(), $sformatf("Starting misaligned control-flow case: %s", label), UVM_LOW)
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
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd1), "SETUP: x1 = 1");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd1), "SETUP: x2 = 1");
    seq.add_instr(seq.rv_b_type(13'd2, 5'd2, 5'd1, 3'b000, 7'b1100011),
                  "MISALIGNED BRANCH: BEQ taken to PC+2, expect halt");
    seq.add_instr(seq.addi(5'd3, 5'd0, 12'd99), "POISON: should not execute after misaligned branch");
    run_halt_case("misaligned branch target", seq);

    seq.clear_program();
    seq.add_instr(seq.rv_j_type(21'd2, 5'd5, 7'b1101111),
                  "MISALIGNED JAL: jump to PC+2, expect halt");
    seq.add_instr(seq.addi(5'd3, 5'd0, 12'd99), "POISON: should not execute after misaligned JAL");
    run_halt_case("misaligned JAL target", seq);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'd2), "SETUP: x1 = 2");
    seq.add_instr(seq.rv_i_type(12'd0, 5'd1, 3'b000, 5'd5, 7'b1100111),
                  "MISALIGNED JALR: target becomes 0x00000002, expect halt");
    seq.add_instr(seq.addi(5'd3, 5'd0, 12'd99), "POISON: should not execute after misaligned JALR");
    run_halt_case("misaligned JALR target", seq);

    `uvm_info(get_type_name(), "=== TEST PASSED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass : cpu_misaligned_control_test
