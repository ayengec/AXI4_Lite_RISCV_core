// cpu_reg_coverage_sweep_test.sv
// Author: Alican Yengec
// Purpose: Targeted functional coverage closure for register and SYSTEM opcode bins.

class cpu_reg_coverage_sweep_test extends cpu_base_test;
  `uvm_component_utils(cpu_reg_coverage_sweep_test)

  function new(string name = "cpu_reg_coverage_sweep_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cpu_reg_coverage_sweep_seq seq = cpu_reg_coverage_sweep_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.body();
    preload_and_start(seq);
    wait_cpu_halt();
    check_final_state();
    phase.drop_objection(this);
  endtask
endclass : cpu_reg_coverage_sweep_test
