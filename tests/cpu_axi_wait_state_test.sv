// cpu_axi_wait_state_test.sv
// Author: Alican Yengec
// Purpose: Directed AXI wait-state coverage test.

class cpu_axi_wait_state_test extends cpu_base_test;
  `uvm_component_utils(cpu_axi_wait_state_test)

  function new(string name = "cpu_axi_wait_state_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cpu_base_seq seq = cpu_base_seq::type_id::create("seq");
    phase.raise_objection(this);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'h200),
                  "SETUP: ADDI x1 = x0 + 0x200 -> data base");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd42),
                  "SETUP: ADDI x2 = 42");
    seq.add_instr(seq.sw(5'd2, 5'd1, 12'h000),
                  "WAIT-STATE STORE: SW x2 -> MEM[0x200], expect 42");
    seq.add_instr(seq.lw(5'd3, 5'd1, 12'h000),
                  "WAIT-STATE LOAD: LW x3 <- MEM[0x200], expect 42");
    seq.add_instr(seq.sw(5'd3, 5'd1, 12'h004),
                  "CHECKPOINT: SW x3 -> MEM[0x204], expect 42");
    seq.add_instr(seq.illegal_instr(),
                  "HALT: illegal instruction 0x00000000 stops CPU");

    vif.clear_axi_controls();
    vif.set_read_wait_cycles(2);
    vif.set_write_wait_cycles(1, 3);

    preload_and_start(seq);
    wait_cpu_halt();
    check_final_state();

    vif.clear_axi_controls();
    phase.drop_objection(this);
  endtask
endclass : cpu_axi_wait_state_test
