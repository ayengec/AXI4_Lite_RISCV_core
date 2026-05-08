// cpu_protocol_assertions.sv
// Author: Alican Yengec
// Purpose: Testbench assertions for RV32I CPU reset and AXI4-Lite protocol behavior.

`include "uvm_macros.svh"

module cpu_protocol_assertions (
  input logic        clk,
  input logic        rst_n,

  input logic [2:0]  cpu_state,
  input logic [31:0] cpu_pc,
  input logic        cpu_mem_is_load,
  input logic        cpu_mem_is_store,
  input logic        cpu_illegal_instr,
  input logic [31:0] cpu_x0,

  input logic        axi_awvalid,
  input logic        axi_awready,
  input logic [31:0] axi_awaddr,
  input logic [2:0]  axi_awprot,

  input logic        axi_wvalid,
  input logic        axi_wready,
  input logic [31:0] axi_wdata,
  input logic [3:0]  axi_wstrb,

  input logic        axi_bvalid,
  input logic        axi_bready,

  input logic        axi_arvalid,
  input logic        axi_arready,
  input logic [31:0] axi_araddr,
  input logic [2:0]  axi_arprot,

  input logic        axi_rvalid,
  input logic        axi_rready
);

  import uvm_pkg::*;

  localparam logic [2:0] ST_FETCH_REQ = 3'd0;
  localparam logic [2:0] ST_MEM_REQ   = 3'd3;
  localparam logic [2:0] ST_HALT      = 3'd5;

  bit read_pending;
  bit write_pending;
  bit aw_seen;
  bit w_seen;

  wire ar_hs = axi_arvalid && axi_arready;
  wire r_hs  = axi_rvalid  && axi_rready;
  wire aw_hs = axi_awvalid && axi_awready;
  wire w_hs  = axi_wvalid  && axi_wready;
  wire b_hs  = axi_bvalid  && axi_bready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      read_pending  <= 1'b0;
      write_pending <= 1'b0;
      aw_seen       <= 1'b0;
      w_seen        <= 1'b0;
    end
    else begin
      if (ar_hs) begin
        if (read_pending)
          `uvm_error("CPU_PROTOCOL_ASSERT", "AXI read request issued while another read response is pending")
        if (write_pending)
          `uvm_error("CPU_PROTOCOL_ASSERT", "AXI read request overlaps an outstanding write transaction")
        read_pending <= 1'b1;
      end

      if (r_hs) begin
        if (!read_pending)
          `uvm_error("CPU_PROTOCOL_ASSERT", "AXI read response accepted without a pending read request")
        read_pending <= 1'b0;
      end

      if (aw_hs || w_hs) begin
        if (read_pending)
          `uvm_error("CPU_PROTOCOL_ASSERT", "AXI write transaction overlaps an outstanding read transaction")
        write_pending <= 1'b1;
      end

      if (aw_hs) begin
        if (aw_seen)
          `uvm_error("CPU_PROTOCOL_ASSERT", "Second AXI AW handshake before BRESP")
        aw_seen <= 1'b1;
      end

      if (w_hs) begin
        if (w_seen)
          `uvm_error("CPU_PROTOCOL_ASSERT", "Second AXI W handshake before BRESP")
        w_seen <= 1'b1;
      end

      if (b_hs) begin
        if (!write_pending)
          `uvm_error("CPU_PROTOCOL_ASSERT", "AXI write response accepted without a pending write request")
        if (!(aw_seen && w_seen))
          `uvm_error("CPU_PROTOCOL_ASSERT", "AXI BRESP accepted before both AW and W handshakes")
        write_pending <= 1'b0;
        aw_seen       <= 1'b0;
        w_seen        <= 1'b0;
      end
    end
  end

  property p_fetch_arprot;
    @(posedge clk) disable iff (!rst_n)
      (axi_arvalid && (cpu_state == ST_FETCH_REQ)) |-> (axi_arprot == 3'b100);
  endproperty

  property p_fetch_araddr_is_pc;
    @(posedge clk) disable iff (!rst_n)
      (axi_arvalid && (cpu_state == ST_FETCH_REQ)) |-> (axi_araddr == cpu_pc);
  endproperty

  property p_data_arprot;
    @(posedge clk) disable iff (!rst_n)
      (axi_arvalid && (cpu_state == ST_MEM_REQ) && cpu_mem_is_load) |-> (axi_arprot == 3'b000);
  endproperty

  property p_data_awprot;
    @(posedge clk) disable iff (!rst_n)
      (axi_awvalid && (cpu_state == ST_MEM_REQ) && cpu_mem_is_store) |-> (axi_awprot == 3'b000);
  endproperty

  property p_no_read_write_valid_overlap;
    @(posedge clk) disable iff (!rst_n)
      !(axi_arvalid && (axi_awvalid || axi_wvalid));
  endproperty

  property p_ar_payload_stable;
    @(posedge clk) disable iff (!rst_n)
      (axi_arvalid && !axi_arready) |=> (axi_arvalid && $stable(axi_araddr) && $stable(axi_arprot));
  endproperty

  property p_aw_payload_stable;
    @(posedge clk) disable iff (!rst_n)
      (axi_awvalid && !axi_awready) |=> (axi_awvalid && $stable(axi_awaddr) && $stable(axi_awprot));
  endproperty

  property p_w_payload_stable;
    @(posedge clk) disable iff (!rst_n)
      (axi_wvalid && !axi_wready) |=> (axi_wvalid && $stable(axi_wdata) && $stable(axi_wstrb));
  endproperty

  property p_reset_state;
    @(posedge clk)
      (!rst_n) |=> ((cpu_pc == rv32i_pkg::RV32I_RESET_VECTOR) &&
                    (cpu_illegal_instr == 1'b0) &&
                    (cpu_x0 == 32'h0000_0000));
  endproperty

  property p_halt_holds_illegal;
    @(posedge clk) disable iff (!rst_n)
      (cpu_state == ST_HALT) |-> (cpu_illegal_instr == 1'b1);
  endproperty

  a_fetch_arprot:
    assert property (p_fetch_arprot)
    else `uvm_error("CPU_PROTOCOL_ASSERT", "Instruction fetch ARPROT must be 3'b100")

  a_fetch_araddr_is_pc:
    assert property (p_fetch_araddr_is_pc)
    else `uvm_error("CPU_PROTOCOL_ASSERT", "Instruction fetch ARADDR must equal current PC")

  a_data_arprot:
    assert property (p_data_arprot)
    else `uvm_error("CPU_PROTOCOL_ASSERT", "Data read ARPROT must be 3'b000")

  a_data_awprot:
    assert property (p_data_awprot)
    else `uvm_error("CPU_PROTOCOL_ASSERT", "Data write AWPROT must be 3'b000")

  a_no_read_write_valid_overlap:
    assert property (p_no_read_write_valid_overlap)
    else `uvm_error("CPU_PROTOCOL_ASSERT", "AXI read and write channels must not be valid in the same cycle")

  a_ar_payload_stable:
    assert property (p_ar_payload_stable)
    else `uvm_error("CPU_PROTOCOL_ASSERT", "ARADDR/ARPROT changed while ARVALID waited for ARREADY")

  a_aw_payload_stable:
    assert property (p_aw_payload_stable)
    else `uvm_error("CPU_PROTOCOL_ASSERT", "AWADDR/AWPROT changed while AWVALID waited for AWREADY")

  a_w_payload_stable:
    assert property (p_w_payload_stable)
    else `uvm_error("CPU_PROTOCOL_ASSERT", "WDATA/WSTRB changed while WVALID waited for WREADY")

  a_reset_state:
    assert property (p_reset_state)
    else `uvm_error("CPU_PROTOCOL_ASSERT", "Reset state must drive reset vector, clear illegal_instr, and keep x0 zero")

  a_halt_holds_illegal:
    assert property (p_halt_holds_illegal)
    else `uvm_error("CPU_PROTOCOL_ASSERT", "ST_HALT must hold illegal_instr asserted")

endmodule : cpu_protocol_assertions
