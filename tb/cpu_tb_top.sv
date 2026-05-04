// cpu_tb_top.sv
// Author: Alican Yengec
// Top-level testbench for RV32I CPU.
// CPU (master) ↔ RAM (slave) directly connected.
// No VIP, no mux — just clean wires.

`timescale 1ns/1ps

module cpu_tb_top;

  import uvm_pkg::*;
  import cpu_tb_pkg::*;

  // ---- Clock --------------------------------------------------
  logic clk;
  parameter CLK_PERIOD = 10;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  cpu_tb_if tb_if(clk);

  // ---- Reset (test-controlled) --------------------------------
  logic rst_n;
  initial rst_n = 1'b0;

  task release_reset();
    `uvm_info("TB_TOP", "Releasing reset", UVM_LOW)
    rst_n = 1'b1;
    repeat(5) @(posedge clk);
  endtask

  task assert_reset();
    @(posedge clk);
    rst_n = 1'b0;
    repeat(5) @(posedge clk);
    @(negedge clk);
  endtask

  // ---- AXI4-Lite wires ---------------------------------------
  logic        awvalid, awready;
  logic [31:0] awaddr;
  logic [2:0]  awprot;
  logic        wvalid, wready;
  logic [31:0] wdata;
  logic [3:0]  wstrb;
  logic        bvalid, bready;
  logic [1:0]  bresp;
  logic        arvalid, arready;
  logic [31:0] araddr;
  logic [2:0]  arprot;
  logic        rvalid, rready;
  logic [31:0] rdata;
  logic [1:0]  rresp;

  // ---- DUT: RV32I CPU (AXI master) ----------------------------
  rv32i_cpu u_cpu (
    .clk            (clk),
    .rst_n          (rst_n),
    .illegal_instr  (),
    .axi_awvalid    (awvalid),
    .axi_awready    (awready),
    .axi_awaddr     (awaddr),
    .axi_awprot     (awprot),
    .axi_wvalid     (wvalid),
    .axi_wready     (wready),
    .axi_wdata      (wdata),
    .axi_wstrb      (wstrb),
    .axi_bvalid     (bvalid),
    .axi_bready     (bready),
    .axi_bresp      (bresp),
    .axi_arvalid    (arvalid),
    .axi_arready    (arready),
    .axi_araddr     (araddr),
    .axi_arprot     (arprot),
    .axi_rvalid     (rvalid),
    .axi_rready     (rready),
    .axi_rdata      (rdata),
    .axi_rresp      (rresp)
  );

  // ---- Slave RAM (256 words = 1 KB) ---------------------------
  axi4lite_ram #(.MEM_DEPTH_WORDS(256)) u_ram (
    .ACLK     (clk),
    .ARESETn  (rst_n),
    .AWVALID  (awvalid),  .AWREADY (awready),
    .AWADDR   (awaddr),   .AWPROT  (awprot),
    .WVALID   (wvalid),   .WREADY  (wready),
    .WDATA    (wdata),    .WSTRB   (wstrb),
    .BVALID   (bvalid),   .BREADY  (bready),
    .BRESP    (bresp),
    .ARVALID  (arvalid),  .ARREADY (arready),
    .ARADDR   (araddr),   .ARPROT  (arprot),
    .RVALID   (rvalid),   .RREADY  (rready),
    .RDATA    (rdata),    .RRESP   (rresp)
  );

  // ---- Optional DUT execution trace ---------------------------
  bit        trace_pending_read;
  bit        trace_pending_instr;
  bit        trace_halt_seen;
  logic [31:0] trace_pending_addr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trace_pending_read  <= 1'b0;
      trace_pending_instr <= 1'b0;
      trace_halt_seen     <= 1'b0;
      trace_pending_addr  <= '0;
    end else begin
      if (arvalid && arready) begin
        trace_pending_read  <= 1'b1;
        trace_pending_instr <= (arprot == 3'b100);
        trace_pending_addr  <= araddr;

        if (arprot == 3'b100)
          `uvm_info("DUT_TRACE", $sformatf(
            "DUT FETCH_REQ  PC=0x%08h", araddr), UVM_LOW)
        else
          `uvm_info("DUT_TRACE", $sformatf(
            "DUT LOAD_REQ   ADDR=0x%08h", araddr), UVM_LOW)
      end

      if (rvalid && rready) begin
        if (trace_pending_instr)
          `uvm_info("DUT_TRACE", $sformatf(
            "DUT FETCH_RSP  PC=0x%08h INSTR=0x%08h", trace_pending_addr, rdata), UVM_LOW)
        else
          `uvm_info("DUT_TRACE", $sformatf(
            "DUT LOAD_RSP   ADDR=0x%08h DATA=0x%08h", trace_pending_addr, rdata), UVM_LOW)

        trace_pending_read <= 1'b0;
      end

      if (u_cpu.rf_we && (u_cpu.rf_waddr != 5'd0)) begin
        `uvm_info("DUT_TRACE", $sformatf(
          "DUT WRITEBACK x%0d <= 0x%08h", u_cpu.rf_waddr, u_cpu.rf_wdata), UVM_LOW)
      end

      if (awvalid && awready && wvalid && wready) begin
        `uvm_info("DUT_TRACE", $sformatf(
          "DUT STORE_REQ  ADDR=0x%08h DATA=0x%08h STRB=0x%0h",
          awaddr, wdata, wstrb), UVM_LOW)
      end

      if (bvalid && bready) begin
        `uvm_info("DUT_TRACE", $sformatf(
          "DUT STORE_RSP  BRESP=0x%0h", bresp), UVM_LOW)
      end

      if ((u_cpu.illegal_instr === 1'b1) && !trace_halt_seen) begin
        `uvm_info("DUT_TRACE", "DUT HALT       illegal_instr=1", UVM_LOW)
        trace_halt_seen <= 1'b1;
      end
    end
  end

  // ---- UVM Test Run -------------------------------------------
  initial begin
    $timeformat(-9, 2, " ns", 20);
    uvm_config_db#(virtual cpu_tb_if)::set(null, "*", "vif", tb_if);
    run_test();
  end

  // Simulation timeout
  initial begin
    #500000ns;
    `uvm_fatal("TB_TOP", "Global simulation timeout (500 us)")
  end

endmodule : cpu_tb_top
