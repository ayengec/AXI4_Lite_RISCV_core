// cpu_random_test.sv
// Author: Alican Yengec
class cpu_random_test extends cpu_base_test;
  `uvm_component_utils(cpu_random_test)

  function new(string name = "cpu_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cpu_random_prog_seq seq = cpu_random_prog_seq::type_id::create("seq");
    phase.raise_objection(this);
    assert(seq.randomize()) else `uvm_fatal(get_type_name(), "Randomization failed")
    seq.body();
    preload_and_start(seq);
    wait_cpu_halt();
    check_final_state();
    phase.drop_objection(this);
  endtask
endclass : cpu_random_test
