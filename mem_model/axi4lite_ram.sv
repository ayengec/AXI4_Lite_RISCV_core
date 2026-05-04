// axi4lite_ram.sv
// Expanded from original by Alican Yengec
//
// AXI4-Lite slave RAM for CPU UVM testbench.
// Parameterizable depth (default 256 words = 1 KB).
// Includes backdoor tasks for UVM test preloading and checking.
//
// Address map (word-aligned, 32-bit words):
//   0x000 - 0x1FF : Instruction region (words 0-127)
//   0x200 - 0x3FF : Data region (words 128-255)
//
// AXI4-Lite slave behaviour:
//   AWREADY and WREADY are always 1 (zero wait state).
//   ARREADY is always 1 (zero wait state).
//   BRESP and RRESP are always OKAY (2'b00).
//   Writes outside the implemented memory window are silently ignored.
//   Reads from undefined addresses return 32'h0.
//   WSTRB is honoured on writes.

`timescale 1ns/1ps

module axi4lite_ram #(
  parameter int MEM_DEPTH_WORDS = 256    // number of implemented 32-bit words
)(
  // ---- AXI4-Lite slave interface ------------------------------
  input  logic        ACLK,
  input  logic        ARESETn,

  // Write Address Channel
  input  logic        AWVALID,
  output logic        AWREADY,
  input  logic [31:0] AWADDR,
  input  logic [2:0]  AWPROT,

  // Write Data Channel
  input  logic        WVALID,
  output logic        WREADY,
  input  logic [31:0] WDATA,
  input  logic [3:0]  WSTRB,

  // Write Response Channel
  output logic        BVALID,
  input  logic        BREADY,
  output logic [1:0]  BRESP,

  // Read Address Channel
  input  logic        ARVALID,
  output logic        ARREADY,
  input  logic [31:0] ARADDR,
  input  logic [2:0]  ARPROT,

  // Read Data Channel
  output logic        RVALID,
  input  logic        RREADY,
  output logic [31:0] RDATA,
  output logic [1:0]  RRESP

);

  // ---- Internal memory ----------------------------------------
  logic [31:0] mem [0:MEM_DEPTH_WORDS-1];

  // ---- AXI4-Lite write handshake capture ----------------------
  logic        wr_en;
  logic [31:0] wr_addr;
  logic [31:0] wr_data;
  logic [3:0]  wr_strb;

  int unsigned wr_idx;
  int unsigned ar_idx;
  logic        wr_addr_hit;
  logic        ar_addr_hit;

  // AWREADY and WREADY are always asserted - zero wait state slave
  assign AWREADY = 1'b1;
  assign WREADY  = 1'b1;
  assign BRESP   = 2'b00;

  // ARREADY is always asserted - zero wait state slave
  assign ARREADY = 1'b1;
  assign RRESP   = 2'b00;

  always_comb begin
    wr_idx      = (wr_addr >> 2);
    ar_idx      = (ARADDR  >> 2);
    // AXI addresses are byte addresses. Byte/halfword accesses may target
    // non-word offsets inside the selected 32-bit word; WSTRB/RDATA slicing
    // handles the byte lane selection.
    wr_addr_hit = (wr_idx < MEM_DEPTH_WORDS);
    ar_addr_hit = (ar_idx < MEM_DEPTH_WORDS);
  end

  // Capture AW/W when both valid in the same cycle.
  always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
      wr_en   <= 1'b0;
      wr_addr <= '0;
      wr_data <= '0;
      wr_strb <= '0;
    end else begin
      wr_en <= AWVALID & WVALID;
      if (AWVALID) wr_addr <= AWADDR;
      if (WVALID) begin
        wr_data <= WDATA;
        wr_strb <= WSTRB;
      end
    end
  end

  // Apply byte enables to a 32-bit word.
  function automatic logic [31:0] apply_strb(
    input logic [31:0] old_val,
    input logic [31:0] new_val,
    input logic [3:0]  strb
  );
    for (int i = 0; i < 4; i++) begin
      apply_strb[i*8 +: 8] = strb[i] ? new_val[i*8 +: 8]
                                     : old_val[i*8 +: 8];
    end
  endfunction

  // ---- Memory write path --------------------------------------
  always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
      for (int i = 0; i < MEM_DEPTH_WORDS; i++)
        mem[i] <= '0;
    end else if (wr_en && wr_addr_hit) begin
      mem[wr_idx] <= apply_strb(mem[wr_idx], wr_data, wr_strb);
    end
  end

  // ---- Write response -----------------------------------------
  always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn)
      BVALID <= 1'b0;
    else if (wr_en)
      BVALID <= 1'b1;
    else if (BVALID && BREADY)
      BVALID <= 1'b0;
  end

  // ---- Memory read path ---------------------------------------
  always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
      RVALID <= 1'b0;
      RDATA  <= '0;
    end else if (ARVALID && ARREADY) begin
      RVALID <= 1'b1;
      if (ar_addr_hit)
        RDATA <= mem[ar_idx];
      else
        RDATA <= 32'h0;
    end else if (RVALID && RREADY) begin
      RVALID <= 1'b0;
    end
  end

  // ==============================================================
  // Backdoor tasks for UVM testbench
  // ==============================================================

  // Preload a 32-bit word at the given byte address (must be word-aligned)
  task automatic preload_word(input logic [31:0] byte_addr, input logic [31:0] data);
    int unsigned idx;
    idx = byte_addr >> 2;
    if (idx < MEM_DEPTH_WORDS) begin
      mem[idx] = data;
    end else begin
      $error("preload_word: address 0x%08h out of range (max 0x%08h)",
             byte_addr, (MEM_DEPTH_WORDS-1)*4);
    end
  endtask

  // Read a 32-bit word from the given byte address (backdoor)
  function automatic logic [31:0] backdoor_read(input logic [31:0] byte_addr);
    int unsigned idx;
    idx = byte_addr >> 2;
    if (idx < MEM_DEPTH_WORDS)
      return mem[idx];
    else
      return 32'h0;
  endfunction

  // Preload an array of instructions starting at byte address 0
  task automatic preload_program(input logic [31:0] program_data[], input int num_words);
    for (int i = 0; i < num_words && i < MEM_DEPTH_WORDS; i++) begin
      mem[i] = program_data[i];
    end
  endtask

  // Clear all memory (for test isolation)
  task automatic clear_mem();
    for (int i = 0; i < MEM_DEPTH_WORDS; i++)
      mem[i] = '0;
  endtask

endmodule : axi4lite_ram
