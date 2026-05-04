// cpu_illegal_instr_test.sv
// Author: Alican Yengec
class cpu_illegal_instr_test extends cpu_base_test;
  `uvm_component_utils(cpu_illegal_instr_test)

  function new(string name = "cpu_illegal_instr_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cpu_base_seq seq = cpu_base_seq::type_id::create("seq");
    phase.raise_objection(this);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'h200),
                  "SETUP: ADDI x1 = x0 + 0x200 -> data base 0x00000200");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd42),
                  "SETUP: ADDI x2 = 42");
    seq.add_instr(seq.sw(5'd2, 5'd1, 12'h000),
                  "CHECKPOINT: SW x2 -> MEM[0x200], expect 42 before halt");
    seq.add_instr(32'h0000000F,
                  "HALT: FENCE/illegal instruction should stop CPU");
    seq.add_instr(seq.addi(5'd3, 5'd0, 12'd999),
                  "POISON: should NOT execute after illegal halt");

    preload_and_start(seq);
    wait_cpu_halt();

    if (vif.illegal_instr())
      `uvm_info(get_type_name(), "PASS: CPU halted on illegal instruction", UVM_LOW)
    else
      `uvm_error(get_type_name(), "FAIL: CPU did not halt")

    check_final_state();
    phase.drop_objection(this);
  endtask
endclass : cpu_illegal_instr_test
