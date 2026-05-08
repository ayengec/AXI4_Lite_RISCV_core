// cpu_alu_imm_corner_test.sv
// Author: Alican Yengec
// Purpose: Targeted SLTI/SLTIU coverage test.

class cpu_alu_imm_corner_test extends cpu_base_test;
  `uvm_component_utils(cpu_alu_imm_corner_test)

  function new(string name = "cpu_alu_imm_corner_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cpu_alu_imm_corner_seq seq = cpu_alu_imm_corner_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.body();
    preload_and_start(seq);
    wait_cpu_halt();
    check_final_state();
    phase.drop_objection(this);
  endtask
endclass : cpu_alu_imm_corner_test
