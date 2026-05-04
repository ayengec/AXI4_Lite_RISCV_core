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
  `include "../sequences/cpu_random_prog_seq.sv"

  // -- Tests --
  `include "../tests/cpu_base_test.sv"
  `include "../tests/cpu_basic_alu_test.sv"
  `include "../tests/cpu_load_store_test.sv"
  `include "../tests/cpu_branch_test.sv"
  `include "../tests/cpu_illegal_instr_test.sv"
  `include "../tests/cpu_random_test.sv"

endpackage : cpu_tb_pkg
