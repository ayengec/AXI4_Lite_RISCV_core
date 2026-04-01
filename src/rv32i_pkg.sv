//==============================================================
// File: rv32i_pkg.sv
// Description: Common package for RV32I CPU design
//
// Shared definitions used across:
//   - rv32i_decoder
//   - rv32i_alu
//   - rv32i_cpu
//   - optional verification components
//==============================================================

package rv32i_pkg;

  // -----------------------------------------------------------
  // Common constants
  // -----------------------------------------------------------
  localparam logic [31:0] RV32I_RESET_VECTOR = 32'h0000_0000;

  localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
  localparam logic [1:0] AXI_RESP_EXOKAY = 2'b01;
  localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;
  localparam logic [1:0] AXI_RESP_DECERR = 2'b11;

  // -----------------------------------------------------------
  // Opcode definitions
  // -----------------------------------------------------------
  typedef enum logic [6:0] {
    OPCODE_LUI      = 7'b0110111,
    OPCODE_AUIPC    = 7'b0010111,
    OPCODE_JAL      = 7'b1101111,
    OPCODE_JALR     = 7'b1100111,
    OPCODE_BRANCH   = 7'b1100011,
    OPCODE_LOAD     = 7'b0000011,
    OPCODE_STORE    = 7'b0100011,
    OPCODE_OP_IMM   = 7'b0010011,
    OPCODE_OP       = 7'b0110011,
    OPCODE_MISC_MEM = 7'b0001111,
    OPCODE_SYSTEM   = 7'b1110011
  } rv32i_opcode_e;

  // -----------------------------------------------------------
  // ALU operation select
  // -----------------------------------------------------------
  typedef enum logic [3:0] {
    ALU_ADD    = 4'd0,
    ALU_SUB    = 4'd1,
    ALU_AND    = 4'd2,
    ALU_OR     = 4'd3,
    ALU_XOR    = 4'd4,
    ALU_SLL    = 4'd5,
    ALU_SRL    = 4'd6,
    ALU_SRA    = 4'd7,
    ALU_SLT    = 4'd8,
    ALU_SLTU   = 4'd9,
    ALU_COPY_B = 4'd10
  } alu_op_e;

  // -----------------------------------------------------------
  // Branch operation select
  // -----------------------------------------------------------
  typedef enum logic [2:0] {
    BR_NONE = 3'd0,
    BR_BEQ  = 3'd1,
    BR_BNE  = 3'd2,
    BR_BLT  = 3'd3,
    BR_BGE  = 3'd4,
    BR_BLTU = 3'd5,
    BR_BGEU = 3'd6
  } branch_op_e;

  // -----------------------------------------------------------
  // Writeback source select
  // -----------------------------------------------------------
  typedef enum logic [1:0] {
    WB_NONE = 2'd0,
    WB_ALU  = 2'd1,
    WB_MEM  = 2'd2,
    WB_PC4  = 2'd3
  } wb_sel_e;

  // -----------------------------------------------------------
  // Memory access size
  // -----------------------------------------------------------
  typedef enum logic [1:0] {
    MEM_NONE = 2'd0,
    MEM_BYTE = 2'd1,
    MEM_HALF = 2'd2,
    MEM_WORD = 2'd3
  } mem_size_e;

endpackage
