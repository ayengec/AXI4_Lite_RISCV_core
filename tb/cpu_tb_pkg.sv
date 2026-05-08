// cpu_tb_pkg.sv
// Author: Alican Yengec
// Testbench package — no VIP dependencies.

package cpu_tb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // -- Environment --
  `include "../env/cpu_ref_model.sv"
  `include "../env/cpu_scoreboard.sv"
  `include "../env/cpu_coverage.sv"
  `include "../env/cpu_env.sv"

  // -- Sequences --
  `include "../sequences/cpu_base_seq.sv"
  `include "../sequences/cpu_basic_alu_seq.sv"
  `include "../sequences/cpu_load_store_seq.sv"
  `include "../sequences/cpu_branch_seq.sv"
  `include "../sequences/cpu_alu_imm_corner_seq.sv"
  `include "../sequences/cpu_branch_corner_seq.sv"
  `include "../sequences/cpu_jump_x0_seq.sv"
  `include "../sequences/cpu_reg_coverage_sweep_seq.sv"
  `include "../sequences/cpu_mem_lane_sweep_seq.sv"
  `include "../sequences/cpu_regfile_semantics_seq.sv"
  `include "../sequences/cpu_address_boundary_seq.sv"
  `include "../sequences/cpu_random_prog_seq.sv"

  // -- Tests --
  `include "../tests/cpu_base_test.sv"
  `include "../tests/cpu_basic_alu_test.sv"
  `include "../tests/cpu_load_store_test.sv"
  `include "../tests/cpu_branch_test.sv"
  `include "../tests/cpu_alu_imm_corner_test.sv"
  `include "../tests/cpu_branch_corner_test.sv"
  `include "../tests/cpu_jump_x0_test.sv"
  `include "../tests/cpu_reg_coverage_sweep_test.sv"
  `include "../tests/cpu_mem_lane_sweep_test.sv"
  `include "../tests/cpu_regfile_semantics_test.sv"
  `include "../tests/cpu_address_boundary_test.sv"
  `include "../tests/cpu_misaligned_access_test.sv"
  `include "../tests/cpu_misaligned_control_test.sv"
  `include "../tests/cpu_invalid_decode_test.sv"
  `include "../tests/cpu_axi_wait_state_test.sv"
  `include "../tests/cpu_axi_error_test.sv"
  `include "../tests/cpu_branch_unit_force_test.sv"
  `include "../tests/cpu_illegal_instr_test.sv"
  `include "../tests/cpu_random_test.sv"

endpackage : cpu_tb_pkg
