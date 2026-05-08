// cpu_axi_error_test.sv
// Author: Alican Yengec
// Purpose: Directed AXI read/write response error halt tests.

class cpu_axi_error_test extends cpu_base_test;
  `uvm_component_utils(cpu_axi_error_test)

  function new(string name = "cpu_axi_error_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task preload_program_only(cpu_base_seq seq);
    `uvm_info(get_type_name(), $sformatf(
      "Preloading %0d instructions into RAM instruction region for AXI error case",
      seq.program_size), UVM_LOW)
    for (int i = 0; i < seq.program_size; i++) begin
      vif.preload_word(i * 4, seq.program_mem[i]);
      `uvm_info(get_type_name(), $sformatf(
        "PRELOAD STEP %03d ADDR=0x%08h INSTR=0x%08h  %s",
        i, i * 4, seq.program_mem[i], seq.program_desc[i]), UVM_LOW)
    end
  endtask

  task run_error_case(string label, cpu_base_seq seq,
                      bit fetch_error, bit data_error, bit write_error);
    `uvm_info(get_type_name(), $sformatf("Starting AXI error case: %s", label), UVM_LOW)

    vif.clear_axi_controls();
    vif.assert_reset();
    preload_program_only(seq);

    if (fetch_error)
      vif.inject_next_fetch_rresp(2'b10);
    if (data_error)
      vif.inject_next_data_rresp(2'b10);
    if (write_error)
      vif.inject_next_bresp(2'b10);

    vif.release_reset();
    wait_cpu_halt();

    if (!vif.illegal_instr())
      `uvm_error(get_type_name(), $sformatf("FAIL: %s did not assert illegal_instr", label))
    else
      `uvm_info(get_type_name(), $sformatf("PASS: %s halted on illegal_instr", label), UVM_LOW)

    vif.clear_axi_controls();
  endtask

  task run_phase(uvm_phase phase);
    cpu_base_seq seq = cpu_base_seq::type_id::create("seq");
    phase.raise_objection(this);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'h200),
                  "FETCH ERROR CASE: first instruction fetch should return SLVERR");
    run_error_case("fetch RRESP SLVERR", seq, 1'b1, 1'b0, 1'b0);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'h200),
                  "SETUP: x1 = data base");
    seq.add_instr(seq.lw(5'd2, 5'd1, 12'h000),
                  "LOAD ERROR CASE: data load should return SLVERR");
    seq.add_instr(seq.addi(5'd3, 5'd0, 12'd99),
                  "POISON: should not execute after load error");
    run_error_case("load RRESP SLVERR", seq, 1'b0, 1'b1, 1'b0);

    seq.clear_program();
    seq.add_instr(seq.addi(5'd1, 5'd0, 12'h200),
                  "SETUP: x1 = data base");
    seq.add_instr(seq.addi(5'd2, 5'd0, 12'd42),
                  "SETUP: x2 = 42");
    seq.add_instr(seq.sw(5'd2, 5'd1, 12'h000),
                  "STORE ERROR CASE: store response should return SLVERR");
    seq.add_instr(seq.addi(5'd3, 5'd0, 12'd99),
                  "POISON: should not execute after store error");
    run_error_case("store BRESP SLVERR", seq, 1'b0, 1'b0, 1'b1);

    `uvm_info(get_type_name(), "=== TEST PASSED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass : cpu_axi_error_test
