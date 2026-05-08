// cpu_regfile_assertions.sv
// Author: Alican Yengec
// Purpose: Testbench assertions for RV32I register-file timing and read behavior.

`include "uvm_macros.svh"

module cpu_regfile_assertions (
  input logic        clk,
  input logic        rst_n
);

  import uvm_pkg::*;

  bit          prev_we;
  logic [4:0]  prev_waddr;
  logic [31:0] prev_wdata;

  always @(posedge clk or negedge rst_n) begin
    bit          curr_we;
    logic [4:0]  curr_waddr;
    logic [31:0] curr_wdata;
    logic [31:0] exp_rdata1;
    logic [31:0] exp_rdata2;

    if (!rst_n) begin
      prev_we    <= 1'b0;
      prev_waddr <= 5'd0;
      prev_wdata <= 32'h0000_0000;
    end
    else begin
      curr_we    = cpu_tb_top.u_cpu.rf_we;
      curr_waddr = cpu_tb_top.u_cpu.rf_waddr;
      curr_wdata = cpu_tb_top.u_cpu.rf_wdata;

      #1ps;

      if (prev_we &&
          (prev_waddr != 5'd0) &&
          (cpu_tb_top.u_cpu.u_regfile.regs[prev_waddr] !== prev_wdata)) begin
        `uvm_error("CPU_REGFILE_ASSERT", $sformatf(
          "Synchronous write failed: x%0d expected 0x%08h got 0x%08h",
          prev_waddr, prev_wdata, cpu_tb_top.u_cpu.u_regfile.regs[prev_waddr]))
      end

      if (cpu_tb_top.u_cpu.u_regfile.regs[0] !== 32'h0000_0000)
        `uvm_error("CPU_REGFILE_ASSERT", $sformatf(
          "x0 must remain zero, got 0x%08h",
          cpu_tb_top.u_cpu.u_regfile.regs[0]))

      exp_rdata1 = (cpu_tb_top.u_cpu.dec_rs1 == 5'd0)
        ? 32'h0000_0000
        : cpu_tb_top.u_cpu.u_regfile.regs[cpu_tb_top.u_cpu.dec_rs1];
      exp_rdata2 = (cpu_tb_top.u_cpu.dec_rs2 == 5'd0)
        ? 32'h0000_0000
        : cpu_tb_top.u_cpu.u_regfile.regs[cpu_tb_top.u_cpu.dec_rs2];

      if (cpu_tb_top.u_cpu.rs1_data !== exp_rdata1) begin
        `uvm_error("CPU_REGFILE_ASSERT", $sformatf(
          "Read port 1 mismatch: raddr=%0d expected 0x%08h got 0x%08h",
          cpu_tb_top.u_cpu.dec_rs1, exp_rdata1, cpu_tb_top.u_cpu.rs1_data))
      end

      if (cpu_tb_top.u_cpu.rs2_data !== exp_rdata2) begin
        `uvm_error("CPU_REGFILE_ASSERT", $sformatf(
          "Read port 2 mismatch: raddr=%0d expected 0x%08h got 0x%08h",
          cpu_tb_top.u_cpu.dec_rs2, exp_rdata2, cpu_tb_top.u_cpu.rs2_data))
      end

      prev_we    <= curr_we;
      prev_waddr <= curr_waddr;
      prev_wdata <= curr_wdata;
    end
  end

endmodule : cpu_regfile_assertions
