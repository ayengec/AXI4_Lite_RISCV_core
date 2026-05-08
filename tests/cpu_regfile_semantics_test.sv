// cpu_regfile_semantics_test.sv
// Author: Alican Yengec
// Purpose: Directed register-file semantics coverage test.

class cpu_regfile_semantics_test extends cpu_base_test;
  `uvm_component_utils(cpu_regfile_semantics_test)

  function new(string name = "cpu_regfile_semantics_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cpu_regfile_semantics_seq seq = cpu_regfile_semantics_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.body();
    preload_and_start(seq);
    wait_cpu_halt();
    check_final_state();
    phase.drop_objection(this);
  endtask
endclass : cpu_regfile_semantics_test
