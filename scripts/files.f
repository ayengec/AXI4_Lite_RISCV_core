// files.f - Compile file list for RV32I CPU UVM testbench
// Usage: xrun -f files.f

// UVM
-uvm

// Timescale
-timescale 1ns/1ps

// ---- CPU RTL ----
../rtl/rv32i_pkg.sv
../rtl/rv32i_regfile.sv
../rtl/rv32i_decoder.sv
../rtl/rv32i_alu.sv
../rtl/rv32i_branch_unit.sv
../rtl/rv32i_cpu.sv

// ---- Slave Memory ----
../mem_model/axi4lite_ram.sv

// ---- TB Interface ----
../tb/cpu_tb_if.sv

// ---- TB Package (includes env, seq, tests) ----
../tb/cpu_tb_pkg.sv

// ---- TB Top ----
../tb/cpu_tb_top.sv
