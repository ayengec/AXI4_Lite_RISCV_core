// cpu_scoreboard.sv
// Author: Alican Yengec
// Compares DUT register file and memory against reference model.

class cpu_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(cpu_scoreboard)

  cpu_ref_model ref_model;
  virtual cpu_tb_if vif;

  function new(string name = "cpu_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual cpu_tb_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "cpu_tb_if was not found in uvm_config_db")
  endfunction

  // Compare DUT registers against reference model
  virtual function int check_registers(logic [31:0] dut_regs[32]);
    int errors = 0;
    for (int i = 0; i < 32; i++) begin
      if (dut_regs[i] !== ref_model.regs[i]) begin
        `uvm_error(get_type_name(), $sformatf(
          "REG MISMATCH x%0d: DUT=0x%08h REF=0x%08h", i, dut_regs[i], ref_model.regs[i]))
        errors++;
      end
    end
    if (errors == 0) `uvm_info(get_type_name(), "All 32 registers MATCH", UVM_LOW)
    return errors;
  endfunction

  // Compare DUT memory against reference model
  virtual function int check_memory(int base_addr, int num_words);
    int errors = 0;
    for (int i = 0; i < num_words; i++) begin
      logic [31:0] addr = base_addr + (i * 4);
      logic [31:0] dut_val = vif.read_mem_word(addr);
      logic [31:0] ref_val = ref_model.mem_read_word(addr);
      if (dut_val !== ref_val) begin
        `uvm_error(get_type_name(), $sformatf(
          "MEM MISMATCH [0x%08h]: DUT=0x%08h REF=0x%08h", addr, dut_val, ref_val))
        errors++;
      end
    end
    if (errors == 0)
      `uvm_info(get_type_name(), $sformatf("Data memory match (%0d words)", num_words), UVM_LOW)
    return errors;
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
  endfunction
endclass : cpu_scoreboard
