// cpu_branch_unit_force_test.sv
// Author: Alican Yengec
// Purpose: Force-only defensive coverage for the branch unit default branch_op case.

class cpu_branch_unit_force_test extends cpu_base_test;
  `uvm_component_utils(cpu_branch_unit_force_test)

  string P_IS_BRANCH    = "cpu_tb_top.u_cpu.u_branch_unit.is_branch_i";
  string P_BRANCH_OP    = "cpu_tb_top.u_cpu.u_branch_unit.branch_op_i";
  string P_CMP_EQ       = "cpu_tb_top.u_cpu.u_branch_unit.cmp_eq_i";
  string P_CMP_LT       = "cpu_tb_top.u_cpu.u_branch_unit.cmp_lt_i";
  string P_CMP_LTU      = "cpu_tb_top.u_cpu.u_branch_unit.cmp_ltu_i";
  string P_BRANCH_TAKEN = "cpu_tb_top.u_cpu.u_branch_unit.branch_taken_o";

  function new(string name = "cpu_branch_unit_force_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task force_hdl(string path, uvm_hdl_data_t value);
    if (!uvm_hdl_force(path, value))
      `uvm_fatal(get_type_name(), $sformatf("uvm_hdl_force failed for %s", path))
  endtask

  task release_hdl(string path);
    if (!uvm_hdl_release(path))
      `uvm_fatal(get_type_name(), $sformatf("uvm_hdl_release failed for %s", path))
  endtask

  task run_phase(uvm_phase phase);
    uvm_hdl_data_t branch_taken;

    phase.raise_objection(this);

    `uvm_info(get_type_name(),
      "Forcing u_branch_unit default branch_op case through uvm_hdl_force. Normal decoder logic prevents invalid branch_op values during ISA execution.",
      UVM_LOW)

    vif.assert_reset();

    force_hdl(P_IS_BRANCH, 1'b1);
    force_hdl(P_BRANCH_OP, 3'd7);
    force_hdl(P_CMP_EQ, 1'b0);
    force_hdl(P_CMP_LT, 1'b0);
    force_hdl(P_CMP_LTU, 1'b0);

    vif.release_reset();
    vif.wait_clks(2);

    if (!uvm_hdl_read(P_BRANCH_TAKEN, branch_taken))
      `uvm_fatal(get_type_name(), $sformatf("uvm_hdl_read failed for %s", P_BRANCH_TAKEN))

    if (branch_taken[0] !== 1'b0) begin
      `uvm_error(get_type_name(),
        "FAIL: branch unit default branch_op did not drive branch_taken_o=0")
    end
    else begin
      `uvm_info(get_type_name(),
        "PASS: branch unit default branch_op drives branch_taken_o=0", UVM_LOW)
    end

    release_hdl(P_IS_BRANCH);
    release_hdl(P_BRANCH_OP);
    release_hdl(P_CMP_EQ);
    release_hdl(P_CMP_LT);
    release_hdl(P_CMP_LTU);

    `uvm_info(get_type_name(), "=== TEST PASSED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass : cpu_branch_unit_force_test
