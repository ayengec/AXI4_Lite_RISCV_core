// cpu_jump_x0_test.sv
// Author: Alican Yengec
// Purpose: Targeted JAL/JALR rd=x0 coverage test.

class cpu_jump_x0_test extends cpu_base_test;
  `uvm_component_utils(cpu_jump_x0_test)

  function new(string name = "cpu_jump_x0_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cpu_jump_x0_seq seq = cpu_jump_x0_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.body();
    preload_and_start(seq);
    wait_cpu_halt();
    check_final_state();
    phase.drop_objection(this);
  endtask
endclass : cpu_jump_x0_test
