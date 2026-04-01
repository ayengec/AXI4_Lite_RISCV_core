//==============================================================
// File: rv32i_regfile.sv
// Description: RV32I Register File
//
// Requirements covered:
//   - RF-001 : 32 general-purpose 32-bit registers
//   - RF-002 : x0 hardwired to zero, writes discarded
//   - RF-003 : x1..x31 reset to zero
//   - RF-004 : synchronous write
//   - RF-005 : asynchronous read
//   - RF-006 : dual read ports
//   - RF-007 : single write port
//   - RF-008 : read-during-write returns new value
//==============================================================

module rv32i_regfile (
  input  logic        clk,
  input  logic        rst_n,

  // RF-007: single write port
  input  logic        we_i,
  input  logic [4:0]  waddr_i,
  input  logic [31:0] wdata_i,

  // RF-006: dual read ports
  input  logic [4:0]  raddr1_i,
  output logic [31:0] rdata1_o,

  input  logic [4:0]  raddr2_i,
  output logic [31:0] rdata2_o
);

  // RF-001: 32 general-purpose integer registers, 32 bits each
  logic [31:0] regs [31:0];
  integer i;

  // RF-003: reset register contents to zero
  // RF-004: writes are synchronous on rising edge of clk
  // rst_n is active-low asynchronous reset per system-level style
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 32; i++) begin
        regs[i] <= 32'h0000_0000;
      end
    end
    else begin
      // RF-002: x0 shall remain hardwired to zero
      regs[0] <= 32'h0000_0000;

      // RF-002: writes to x0 are silently discarded
      if (we_i && (waddr_i != 5'd0)) begin
        regs[waddr_i] <= wdata_i;
      end
    end
  end

  // RF-005: asynchronous read
  // RF-008: if read and write target same register in same cycle,
  //         return the new written value via bypass
  always_comb begin
    if (raddr1_i == 5'd0) begin
      // RF-002: x0 always reads as zero
      rdata1_o = 32'h0000_0000;
    end
    else if (we_i && (waddr_i == raddr1_i) && (waddr_i != 5'd0)) begin
      // RF-008: read-during-write forwarding
      rdata1_o = wdata_i;
    end
    else begin
      rdata1_o = regs[raddr1_i];
    end
  end

  // RF-005: asynchronous read
  // RF-008: if read and write target same register in same cycle,
  //         return the new written value via bypass
  always_comb begin
    if (raddr2_i == 5'd0) begin
      // RF-002: x0 always reads as zero
      rdata2_o = 32'h0000_0000;
    end
    else if (we_i && (waddr_i == raddr2_i) && (waddr_i != 5'd0)) begin
      // RF-008: read-during-write forwarding
      rdata2_o = wdata_i;
    end
    else begin
      rdata2_o = regs[raddr2_i];
    end
  end

endmodule
