// axi4lite_ram.sv
// Author: Alican Yengec
// Purpose: Simple AXI4-Lite RAM model with backdoor preload/readback and
//          test-controlled wait-state/error-response injection.
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
//   AWREADY, WREADY, and ARREADY default to zero wait state.
//   BRESP and RRESP default to OKAY (2'b00).
//   Backdoor tasks can inject wait states and one-shot response errors.
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

  int unsigned cfg_ar_wait_cycles;
  int unsigned cfg_aw_wait_cycles;
  int unsigned cfg_w_wait_cycles;
  int unsigned ar_wait_count;
  int unsigned aw_wait_count;
  int unsigned w_wait_count;
  logic        ar_wait_active;
  logic        aw_wait_active;
  logic        w_wait_active;

  logic        aw_seen;
  logic        w_seen;

  logic        inject_fetch_rresp_valid;
  logic        inject_data_rresp_valid;
  logic        inject_bresp_valid;
  logic [1:0]  inject_fetch_rresp;
  logic [1:0]  inject_data_rresp;
  logic [1:0]  inject_bresp;

  wire aw_fire = AWVALID && AWREADY;
  wire w_fire  = WVALID  && WREADY;
  wire ar_fire = ARVALID && ARREADY;

  always_comb begin
    wr_idx      = (wr_addr >> 2);
    ar_idx      = (ARADDR  >> 2);
    // AXI addresses are byte addresses. Byte/halfword accesses may target
    // non-word offsets inside the selected 32-bit word; WSTRB/RDATA slicing
    // handles the byte lane selection.
    wr_addr_hit = (wr_idx < MEM_DEPTH_WORDS);
    ar_addr_hit = (ar_idx < MEM_DEPTH_WORDS);
  end

  task automatic update_ready(
    input  logic        valid,
    input  int unsigned cfg_wait_cycles,
    inout  logic        ready,
    inout  logic        wait_active,
    inout  int unsigned wait_count
  );
    if (!valid) begin
      ready       = (cfg_wait_cycles == 0);
      wait_active = 1'b0;
      wait_count  = 0;
    end
    else if (!wait_active) begin
      if (cfg_wait_cycles == 0) begin
        ready = 1'b1;
      end
      else begin
        ready       = 1'b0;
        wait_active = 1'b1;
        wait_count  = 0;
      end
    end
    else if ((wait_count + 1) >= cfg_wait_cycles) begin
      ready = 1'b1;
    end
    else begin
      ready      = 1'b0;
      wait_count = wait_count + 1;
    end

    if (valid && ready) begin
      ready       = (cfg_wait_cycles == 0);
      wait_active = 1'b0;
      wait_count  = 0;
    end
  endtask

  // READY generation, defaulting to zero wait state.
  always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
      AWREADY        <= (cfg_aw_wait_cycles == 0);
      WREADY         <= (cfg_w_wait_cycles  == 0);
      ARREADY        <= (cfg_ar_wait_cycles == 0);
      aw_wait_active <= 1'b0;
      w_wait_active  <= 1'b0;
      ar_wait_active <= 1'b0;
      aw_wait_count  <= 0;
      w_wait_count   <= 0;
      ar_wait_count  <= 0;
    end else begin
      update_ready(AWVALID, cfg_aw_wait_cycles, AWREADY, aw_wait_active, aw_wait_count);
      update_ready(WVALID,  cfg_w_wait_cycles,  WREADY,  w_wait_active,  w_wait_count);
      update_ready(ARVALID, cfg_ar_wait_cycles, ARREADY, ar_wait_active, ar_wait_count);
    end
  end

  // Capture AW/W independently and perform a write once both channels arrived.
  always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
      wr_en   <= 1'b0;
      wr_addr <= '0;
      wr_data <= '0;
      wr_strb <= '0;
      aw_seen <= 1'b0;
      w_seen  <= 1'b0;
    end else begin
      wr_en <= 1'b0;

      if (aw_fire) begin
        wr_addr <= AWADDR;
        aw_seen <= 1'b1;
      end

      if (w_fire) begin
        wr_data <= WDATA;
        wr_strb <= WSTRB;
        w_seen  <= 1'b1;
      end

      if ((aw_seen || aw_fire) && (w_seen || w_fire) && !BVALID) begin
        wr_en  <= 1'b1;
        aw_seen <= 1'b0;
        w_seen  <= 1'b0;
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
    if (!ARESETn) begin
      BVALID <= 1'b0;
      BRESP  <= 2'b00;
    end
    else if (wr_en) begin
      BVALID <= 1'b1;
      BRESP  <= inject_bresp_valid ? inject_bresp : 2'b00;
      inject_bresp_valid <= 1'b0;
    end
    else if (BVALID && BREADY) begin
      BVALID <= 1'b0;
      BRESP  <= 2'b00;
    end
  end

  // ---- Memory read path ---------------------------------------
  always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
      RVALID <= 1'b0;
      RDATA  <= '0;
      RRESP  <= 2'b00;
    end else if (ar_fire) begin
      RVALID <= 1'b1;
      if (ARPROT == 3'b100 && inject_fetch_rresp_valid) begin
        RRESP <= inject_fetch_rresp;
        inject_fetch_rresp_valid <= 1'b0;
      end
      else if (ARPROT != 3'b100 && inject_data_rresp_valid) begin
        RRESP <= inject_data_rresp;
        inject_data_rresp_valid <= 1'b0;
      end
      else begin
        RRESP <= 2'b00;
      end

      if (ar_addr_hit)
        RDATA <= mem[ar_idx];
      else
        RDATA <= 32'h0;
    end else if (RVALID && RREADY) begin
      RVALID <= 1'b0;
      RRESP  <= 2'b00;
    end
  end

  // ==============================================================
  // Backdoor tasks for UVM testbench
  // ==============================================================

  initial begin
    clear_axi_controls();
  end

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

  task automatic clear_axi_controls();
    cfg_ar_wait_cycles       = 0;
    cfg_aw_wait_cycles       = 0;
    cfg_w_wait_cycles        = 0;
    inject_fetch_rresp_valid = 1'b0;
    inject_data_rresp_valid  = 1'b0;
    inject_bresp_valid       = 1'b0;
    inject_fetch_rresp       = 2'b00;
    inject_data_rresp        = 2'b00;
    inject_bresp             = 2'b00;
  endtask

  task automatic set_read_wait_cycles(input int unsigned cycles);
    cfg_ar_wait_cycles = cycles;
  endtask

  task automatic set_write_wait_cycles(input int unsigned aw_cycles,
                                       input int unsigned w_cycles);
    cfg_aw_wait_cycles = aw_cycles;
    cfg_w_wait_cycles  = w_cycles;
  endtask

  task automatic inject_next_fetch_rresp(input logic [1:0] resp);
    inject_fetch_rresp       = resp;
    inject_fetch_rresp_valid = 1'b1;
  endtask

  task automatic inject_next_data_rresp(input logic [1:0] resp);
    inject_data_rresp       = resp;
    inject_data_rresp_valid = 1'b1;
  endtask

  task automatic inject_next_bresp(input logic [1:0] resp);
    inject_bresp       = resp;
    inject_bresp_valid = 1'b1;
  endtask

endmodule : axi4lite_ram
