// cpu_env.sv
// Author: Alican Yengec
// Simplified UVM environment: scoreboard + reference model only.
// No VIP, no reg layer.

class cpu_env extends uvm_env;
  `uvm_component_utils(cpu_env)

  cpu_scoreboard sb;
  cpu_ref_model  ref_model;
  cpu_coverage   cov;

  function new(string name = "cpu_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sb        = cpu_scoreboard::type_id::create("sb", this);
    ref_model = cpu_ref_model::type_id::create("ref_model", this);
    cov       = cpu_coverage::type_id::create("cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    sb.ref_model = ref_model;
    ref_model.instr_ap.connect(cov.analysis_export);
  endfunction
endclass : cpu_env
