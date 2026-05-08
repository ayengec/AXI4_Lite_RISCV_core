// cpu_branch_corner_test.sv
// Author: Alican Yengec
// Purpose: Targeted unsigned branch direction coverage test.

class cpu_branch_corner_test extends cpu_base_test;
  `uvm_component_utils(cpu_branch_corner_test)

  function new(string name = "cpu_branch_corner_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cpu_branch_corner_seq seq = cpu_branch_corner_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.body();
    preload_and_start(seq);
    wait_cpu_halt();
    check_final_state();
    phase.drop_objection(this);
  endtask
endclass : cpu_branch_corner_test
