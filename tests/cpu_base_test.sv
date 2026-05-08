// cpu_base_test.sv
// Author: Alican Yengec
// Base test: backdoor preload → release reset → CPU runs → backdoor check.

class cpu_base_test extends uvm_test;
  `uvm_component_utils(cpu_base_test)

  cpu_env env;
  virtual cpu_tb_if vif;
  int unsigned sim_timeout = 100000;

  function new(string name = "cpu_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual cpu_tb_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "cpu_tb_if was not found in uvm_config_db")
    env = cpu_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  // Backdoor preload program into RAM + setup reference model
  task preload_and_start(cpu_base_seq program_seq);
    // Hold reset active through a few clocks before backdoor preload.
    // The RAM model clears memory on reset clock edges, so preload must happen
    // after those reset edges and before reset is deasserted.
    vif.assert_reset();

    // Preload into DUT RAM (backdoor)
    `uvm_info(get_type_name(), $sformatf(
      "Preloading %0d instructions into RAM instruction region", program_seq.program_size), UVM_LOW)
    for (int i = 0; i < program_seq.program_size; i++) begin
      vif.preload_word(i * 4, program_seq.program_mem[i]);
      `uvm_info(get_type_name(), $sformatf(
        "PRELOAD STEP %03d ADDR=0x%08h INSTR=0x%08h  %s",
        i, i * 4, program_seq.program_mem[i], program_seq.program_desc[i]), UVM_LOW)
    end

    // Run reference model (software ISS)
    env.ref_model.reset();
    env.ref_model.preload_program(program_seq.program_mem, program_seq.program_size);
    env.ref_model.run_program();
    env.ref_model.print_state();

    // Release reset → CPU starts fetching
    vif.release_reset();
  endtask

  task preload_and_start_no_ref(cpu_base_seq program_seq);
    vif.assert_reset();

    `uvm_info(get_type_name(), $sformatf(
      "Preloading %0d instructions into RAM instruction region without reference-model run",
      program_seq.program_size), UVM_LOW)
    for (int i = 0; i < program_seq.program_size; i++) begin
      vif.preload_word(i * 4, program_seq.program_mem[i]);
      `uvm_info(get_type_name(), $sformatf(
        "PRELOAD STEP %03d ADDR=0x%08h INSTR=0x%08h  %s",
        i, i * 4, program_seq.program_mem[i], program_seq.program_desc[i]), UVM_LOW)
    end

    vif.release_reset();
  endtask

  // Wait for CPU halt
  task wait_cpu_halt();
    fork
      begin
        vif.wait_illegal_instr();
        `uvm_info(get_type_name(), "CPU halted", UVM_LOW)
      end
      begin
        #(sim_timeout * 1ns);
        `uvm_fatal(get_type_name(), "Timeout")
      end
    join_any
    disable fork;
    vif.wait_clks(10);
  endtask

  // Check final state via backdoor
  task check_final_state();
    logic [31:0] dut_regs[32];
    int reg_err, mem_err;

    // Read DUT regfile (backdoor)
    for (int i = 0; i < 32; i++)
      dut_regs[i] = vif.read_reg(i);

    reg_err = env.sb.check_registers(dut_regs);
    mem_err = env.sb.check_memory(32'h200, 32);  // data region

    if (reg_err == 0 && mem_err == 0)
      `uvm_info(get_type_name(), "=== TEST PASSED ===", UVM_LOW)
    else
      `uvm_error(get_type_name(), $sformatf("=== TEST FAILED === reg=%0d mem=%0d", reg_err, mem_err))
  endtask

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
  endtask
endclass : cpu_base_test
