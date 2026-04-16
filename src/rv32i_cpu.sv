//==============================================================
// File: rv32i_cpu.sv
// Description: Top-level RV32I CPU with single AXI4-Lite master
//==============================================================

import rv32i_pkg::*;

module rv32i_cpu (
  input  logic        clk,
  input  logic        rst_n,

  // EXC-001/002/003/004
  output logic        illegal_instr,

  // Single AXI4-Lite master interface
  output logic        axi_awvalid,
  input  logic        axi_awready,
  output logic [31:0] axi_awaddr,
  output logic [2:0]  axi_awprot,

  output logic        axi_wvalid,
  input  logic        axi_wready,
  output logic [31:0] axi_wdata,
  output logic [3:0]  axi_wstrb,

  input  logic        axi_bvalid,
  output logic        axi_bready,
  input  logic [1:0]  axi_bresp,

  output logic        axi_arvalid,
  input  logic        axi_arready,
  output logic [31:0] axi_araddr,
  output logic [2:0]  axi_arprot,

  input  logic        axi_rvalid,
  output logic        axi_rready,
  input  logic [31:0] axi_rdata,
  input  logic [1:0]  axi_rresp
);

  typedef enum logic [2:0] {
    ST_FETCH_REQ  = 3'd0,
    ST_FETCH_WAIT = 3'd1,
    ST_EXECUTE    = 3'd2,
    ST_MEM_REQ    = 3'd3,
    ST_MEM_WAIT   = 3'd4,
    ST_HALT       = 3'd5
  } state_e;

  state_e state_q, state_d;

  logic [31:0] pc_q, pc_d;
  logic [31:0] instr_q, instr_d;

  logic        illegal_q, illegal_d;

  logic [31:0] mem_addr_q,  mem_addr_d;
  logic [31:0] mem_wdata_q, mem_wdata_d;
  logic [3:0]  mem_wstrb_q, mem_wstrb_d;
  logic        mem_is_load_q,  mem_is_load_d;
  logic        mem_is_store_q, mem_is_store_d;
  logic        mem_load_unsigned_q, mem_load_unsigned_d;
  mem_size_e   mem_size_q, mem_size_d;
  logic [4:0]  mem_rd_q, mem_rd_d;
  logic        mem_reg_write_q, mem_reg_write_d;

  // AXI request tracking
  logic fetch_ar_done_q, fetch_ar_done_d;
  logic mem_ar_done_q,   mem_ar_done_d;
  logic mem_aw_done_q,   mem_aw_done_d;
  logic mem_w_done_q,    mem_w_done_d;

  // Regfile
  logic        rf_we;
  logic [4:0]  rf_waddr;
  logic [31:0] rf_wdata;
  logic [31:0] rs1_data, rs2_data;

  // Decoder outputs
  logic [6:0]  dec_opcode;
  logic [4:0]  dec_rs1, dec_rs2, dec_rd;
  logic [2:0]  dec_funct3;
  logic [6:0]  dec_funct7;
  logic [31:0] dec_imm_i, dec_imm_s, dec_imm_b, dec_imm_u, dec_imm_j;
  logic        dec_use_rs1, dec_use_rs2;
  logic        dec_reg_write;
  logic        dec_alu_src_imm;
  alu_op_e     dec_alu_op;
  wb_sel_e     dec_wb_sel;
  logic        dec_is_branch, dec_is_jal, dec_is_jalr;
  branch_op_e  dec_branch_op;
  logic        dec_is_load, dec_is_store;
  mem_size_e   dec_mem_size;
  logic        dec_load_unsigned;
  logic        dec_op_a_is_pc, dec_op_b_is_uimm;
  logic        dec_illegal;

  // ALU / branch
  logic [31:0] alu_op_a, alu_op_b;
  logic [31:0] alu_result;
  logic        cmp_eq, cmp_lt, cmp_ltu;

  logic        branch_taken;
  logic [31:0] branch_target, jal_target, jalr_target;
  logic        branch_target_misaligned;
  logic        jal_target_misaligned;
  logic        jalr_target_misaligned;

  logic [31:0] next_pc_seq;
  logic [31:0] next_pc_ctrl;
  logic        next_pc_ctrl_valid;

  logic [31:0] load_data_ext;
  logic        mem_addr_misaligned;

  //============================================================
  // Submodules
  //============================================================

  rv32i_regfile u_regfile (
    .clk     (clk),
    .rst_n   (rst_n),
    .we_i    (rf_we),
    .waddr_i (rf_waddr),
    .wdata_i (rf_wdata),
    .raddr1_i(dec_rs1),
    .rdata1_o(rs1_data),
    .raddr2_i(dec_rs2),
    .rdata2_o(rs2_data)
  );

  rv32i_decoder u_decoder (
    .instr_i                    (instr_q),
    .opcode_o                   (dec_opcode),
    .rs1_o                      (dec_rs1),
    .rs2_o                      (dec_rs2),
    .rd_o                       (dec_rd),
    .funct3_o                   (dec_funct3),
    .funct7_o                   (dec_funct7),
    .imm_i_type_o               (dec_imm_i),
    .imm_s_type_o               (dec_imm_s),
    .imm_b_type_o               (dec_imm_b),
    .imm_u_type_o               (dec_imm_u),
    .imm_j_type_o               (dec_imm_j),
    .use_rs1_o                  (dec_use_rs1),
    .use_rs2_o                  (dec_use_rs2),
    .reg_write_o                (dec_reg_write),
    .alu_src_imm_o              (dec_alu_src_imm),
    .alu_op_o                   (dec_alu_op),
    .wb_sel_o                   (dec_wb_sel),
    .is_branch_o                (dec_is_branch),
    .is_jal_o                   (dec_is_jal),
    .is_jalr_o                  (dec_is_jalr),
    .branch_op_o                (dec_branch_op),
    .is_load_o                  (dec_is_load),
    .is_store_o                 (dec_is_store),
    .mem_size_o                 (dec_mem_size),
    .load_unsigned_o            (dec_load_unsigned),
    .op_a_is_pc_o               (dec_op_a_is_pc),
    .op_b_is_uimm_o             (dec_op_b_is_uimm),
    .illegal_instr_o            (dec_illegal)
  );

  rv32i_alu u_alu (
    .alu_op_i (dec_alu_op),
    .op_a_i   (alu_op_a),
    .op_b_i   (alu_op_b),
    .result_o (alu_result),
    .cmp_eq_o (cmp_eq),
    .cmp_lt_o (cmp_lt),
    .cmp_ltu_o(cmp_ltu)
  );

  rv32i_branch_unit u_branch_unit (
    .pc_i                        (pc_q),
    .rs1_i                       (rs1_data),
    .b_imm_i                     (dec_imm_b),
    .j_imm_i                     (dec_imm_j),
    .i_imm_i                     (dec_imm_i),
    .is_branch_i                 (dec_is_branch),
    .is_jal_i                    (dec_is_jal),
    .is_jalr_i                   (dec_is_jalr),
    .branch_op_i                 (dec_branch_op),
    .cmp_eq_i                    (cmp_eq),
    .cmp_lt_i                    (cmp_lt),
    .cmp_ltu_i                   (cmp_ltu),
    .branch_taken_o              (branch_taken),
    .branch_target_o             (branch_target),
    .jal_target_o                (jal_target),
    .jalr_target_o               (jalr_target),
    .branch_target_misaligned_o  (branch_target_misaligned),
    .jal_target_misaligned_o     (jal_target_misaligned),
    .jalr_target_misaligned_o    (jalr_target_misaligned)
  );

  //============================================================
  // Operand muxing
  //============================================================

  always_comb begin
    if (dec_op_a_is_pc) begin
      alu_op_a = pc_q;                                    // ALU-015
    end
    else begin
      alu_op_a = rs1_data;
    end

    if (dec_op_b_is_uimm) begin
      alu_op_b = dec_imm_u;                               // ALU-014, ALU-015
    end
    else if (dec_alu_src_imm) begin
      if (dec_is_store) begin
        alu_op_b = dec_imm_s;                             // MEM-006/007/008
      end
      else begin
        alu_op_b = dec_imm_i;                             // ALU-003 etc.
      end
    end
    else begin
      alu_op_b = rs2_data;
    end
  end

  assign next_pc_seq = pc_q + 32'd4;                      // IF-002

  always_comb begin
    next_pc_ctrl_valid = 1'b0;
    next_pc_ctrl       = next_pc_seq;

    if (dec_is_jal) begin
      next_pc_ctrl_valid = 1'b1;
      next_pc_ctrl       = jal_target;                    // IF-004, JMP-001
    end
    else if (dec_is_jalr) begin
      next_pc_ctrl_valid = 1'b1;
      next_pc_ctrl       = jalr_target;                   // IF-004, JMP-002
    end
    else if (dec_is_branch && branch_taken) begin
      next_pc_ctrl_valid = 1'b1;
      next_pc_ctrl       = branch_target;                 // IF-003, BRN-001..006
    end
  end

  //============================================================
  // Misalignment checks
  //============================================================

  always_comb begin
    mem_addr_misaligned = 1'b0;

    unique case (dec_mem_size)
      MEM_WORD: mem_addr_misaligned = |alu_result[1:0];   // MEM-015
      MEM_HALF: mem_addr_misaligned =  alu_result[0];     // MEM-016
      default:  mem_addr_misaligned = 1'b0;
    endcase
  end

  //============================================================
  // Store data / strobe generation
  //============================================================

  function automatic logic [3:0] gen_wstrb (
    input mem_size_e   size,
    input logic [1:0]  addr_lsb
  );
    logic [3:0] tmp;
    begin
      tmp = 4'b0000;
      unique case (size)
        MEM_WORD: tmp = 4'b1111;                          // MEM-012
        MEM_HALF: tmp = addr_lsb[1] ? 4'b1100 : 4'b0011; // MEM-012
        MEM_BYTE: begin
          unique case (addr_lsb)
            2'd0: tmp = 4'b0001;
            2'd1: tmp = 4'b0010;
            2'd2: tmp = 4'b0100;
            2'd3: tmp = 4'b1000;
            default: tmp = 4'b0000;
          endcase
        end
        default: tmp = 4'b0000;
      endcase
      return tmp;
    end
  endfunction

  function automatic logic [31:0] gen_store_wdata (
    input mem_size_e   size,
    input logic [1:0]  addr_lsb,
    input logic [31:0] rs2_val
  );
    logic [31:0] tmp;
    begin
      tmp = 32'h0000_0000;
      unique case (size)
        MEM_WORD: tmp = rs2_val;                          // MEM-006
        MEM_HALF: tmp = addr_lsb[1] ? {rs2_val[15:0], 16'h0}
                                    : {16'h0, rs2_val[15:0]}; // MEM-007
        MEM_BYTE: begin                                   // MEM-008
          unique case (addr_lsb)
            2'd0: tmp = {24'h0, rs2_val[7:0]};
            2'd1: tmp = {16'h0, rs2_val[7:0], 8'h0};
            2'd2: tmp = { 8'h0, rs2_val[7:0],16'h0};
            2'd3: tmp = {rs2_val[7:0],24'h0};
            default: tmp = 32'h0000_0000;
          endcase
        end
        default: tmp = 32'h0000_0000;
      endcase
      return tmp;
    end
  endfunction

  //============================================================
  // Load extraction / extension
  //============================================================

  always_comb begin
    logic [15:0] hword;
    logic [7:0]  byte_val;

    hword        = 16'h0000;
    byte_val     = 8'h00;
    load_data_ext = 32'h0000_0000;

    unique case (mem_size_q)
      MEM_WORD: begin
        load_data_ext = axi_rdata;                        // MEM-001
      end

      MEM_HALF: begin
        hword = mem_addr_q[1] ? axi_rdata[31:16] : axi_rdata[15:0];

        if (mem_load_unsigned_q) begin
          load_data_ext = {16'h0000, hword};              // MEM-003
        end
        else begin
          load_data_ext = {{16{hword[15]}}, hword};       // MEM-002
        end
      end

      MEM_BYTE: begin
        unique case (mem_addr_q[1:0])
          2'd0: byte_val = axi_rdata[7:0];
          2'd1: byte_val = axi_rdata[15:8];
          2'd2: byte_val = axi_rdata[23:16];
          2'd3: byte_val = axi_rdata[31:24];
          default: byte_val = 8'h00;
        endcase

        if (mem_load_unsigned_q) begin
          load_data_ext = {24'h000000, byte_val};         // MEM-005
        end
        else begin
          load_data_ext = {{24{byte_val[7]}}, byte_val};  // MEM-004
        end
      end

      default: begin
        load_data_ext = 32'h0000_0000;
      end
    endcase
  end

  //============================================================
  // Register writeback
  //============================================================

  always_comb begin
    rf_we    = 1'b0;
    rf_waddr = 5'd0;
    rf_wdata = 32'h0000_0000;

    if (state_q == ST_EXECUTE) begin
      if (!illegal_q && !dec_illegal) begin
        if (!dec_is_load && !dec_is_store && dec_reg_write) begin
          rf_we    = (dec_rd != 5'd0);                    // RF-002, RF-007
          rf_waddr = dec_rd;

          unique case (dec_wb_sel)
            WB_ALU: rf_wdata = alu_result;
            WB_PC4: rf_wdata = next_pc_seq;               // JMP-001, JMP-002
            default: rf_wdata = 32'h0000_0000;
          endcase
        end
      end
    end
    else if (state_q == ST_MEM_WAIT) begin
      if (mem_is_load_q && axi_rvalid &&
          (axi_rresp == AXI_RESP_OKAY) &&
          mem_reg_write_q) begin
        rf_we    = (mem_rd_q != 5'd0);
        rf_waddr = mem_rd_q;
        rf_wdata = load_data_ext;                         // MEM-001..005
      end
    end
  end

  //============================================================
  // Sequential
  //============================================================

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q             <= ST_FETCH_REQ;                // SYS-005
      pc_q                <= RV32I_RESET_VECTOR;          // SYS-006
      instr_q             <= 32'h0000_0013;
      illegal_q           <= 1'b0;

      mem_addr_q          <= 32'h0000_0000;
      mem_wdata_q         <= 32'h0000_0000;
      mem_wstrb_q         <= 4'b0000;
      mem_is_load_q       <= 1'b0;
      mem_is_store_q      <= 1'b0;
      mem_load_unsigned_q <= 1'b0;
      mem_size_q          <= MEM_NONE;
      mem_rd_q            <= 5'd0;
      mem_reg_write_q     <= 1'b0;

      fetch_ar_done_q     <= 1'b0;
      mem_ar_done_q       <= 1'b0;
      mem_aw_done_q       <= 1'b0;
      mem_w_done_q        <= 1'b0;
    end
    else begin
      state_q             <= state_d;
      pc_q                <= pc_d;
      instr_q             <= instr_d;
      illegal_q           <= illegal_d;

      mem_addr_q          <= mem_addr_d;
      mem_wdata_q         <= mem_wdata_d;
      mem_wstrb_q         <= mem_wstrb_d;
      mem_is_load_q       <= mem_is_load_d;
      mem_is_store_q      <= mem_is_store_d;
      mem_load_unsigned_q <= mem_load_unsigned_d;
      mem_size_q          <= mem_size_d;
      mem_rd_q            <= mem_rd_d;
      mem_reg_write_q     <= mem_reg_write_d;

      fetch_ar_done_q     <= fetch_ar_done_d;
      mem_ar_done_q       <= mem_ar_done_d;
      mem_aw_done_q       <= mem_aw_done_d;
      mem_w_done_q        <= mem_w_done_d;
    end
  end

  assign illegal_instr = illegal_q;

  //============================================================
  // Next-state
  //============================================================

  always_comb begin
    state_d             = state_q;
    pc_d                = pc_q;
    instr_d             = instr_q;
    illegal_d           = illegal_q;

    mem_addr_d          = mem_addr_q;
    mem_wdata_d         = mem_wdata_q;
    mem_wstrb_d         = mem_wstrb_q;
    mem_is_load_d       = mem_is_load_q;
    mem_is_store_d      = mem_is_store_q;
    mem_load_unsigned_d = mem_load_unsigned_q;
    mem_size_d          = mem_size_q;
    mem_rd_d            = mem_rd_q;
    mem_reg_write_d     = mem_reg_write_q;

    fetch_ar_done_d     = fetch_ar_done_q;
    mem_ar_done_d       = mem_ar_done_q;
    mem_aw_done_d       = mem_aw_done_q;
    mem_w_done_d        = mem_w_done_q;

    unique case (state_q)

      ST_FETCH_REQ: begin
        if (pc_q[1:0] != 2'b00) begin
          illegal_d = 1'b1;                               // IF-005, EXC-003
          state_d   = ST_HALT;                            // EXC-002
        end
        else begin
          // Advance only on a real AXI AR handshake.
          // Checking only axi_arready can miss the request when reset is
          // deasserted on a clock edge and axi_arvalid was still 0 in that cycle.
          if (!fetch_ar_done_q && axi_arvalid && axi_arready) begin
            fetch_ar_done_d = 1'b1;
          end

          if (fetch_ar_done_q || (axi_arvalid && axi_arready)) begin
            fetch_ar_done_d = 1'b0;
            state_d         = ST_FETCH_WAIT;
          end
        end
      end

      ST_FETCH_WAIT: begin
        if (axi_rvalid) begin
          if (axi_rresp != AXI_RESP_OKAY) begin
            illegal_d = 1'b1;
            state_d   = ST_HALT;
          end
          else begin
            instr_d = axi_rdata;                          // IF-001
            state_d = ST_EXECUTE;
          end
        end
      end

      ST_EXECUTE: begin
        if (dec_illegal) begin
          illegal_d = 1'b1;                               // ID-012, EXC-001
          state_d   = ST_HALT;                            // EXC-002
        end
        else if ((dec_is_branch && branch_taken && branch_target_misaligned) ||
                 (dec_is_jal    && jal_target_misaligned) ||
                 (dec_is_jalr   && jalr_target_misaligned)) begin
          illegal_d = 1'b1;                               // BRN-007 + alignment policy
          state_d   = ST_HALT;                            // EXC-002
        end
        else if (dec_is_load || dec_is_store) begin
          if (mem_addr_misaligned) begin
            illegal_d = 1'b1;                             // EXC-004
            state_d   = ST_HALT;                          // EXC-002
          end
          else begin
            mem_addr_d          = alu_result;
            mem_is_load_d       = dec_is_load;
            mem_is_store_d      = dec_is_store;
            mem_load_unsigned_d = dec_load_unsigned;
            mem_size_d          = dec_mem_size;
            mem_rd_d            = dec_rd;
            mem_reg_write_d     = dec_reg_write;
            mem_wstrb_d         = gen_wstrb(dec_mem_size, alu_result[1:0]);
            mem_wdata_d         = gen_store_wdata(dec_mem_size, alu_result[1:0], rs2_data);

            mem_ar_done_d       = 1'b0;
            mem_aw_done_d       = 1'b0;
            mem_w_done_d        = 1'b0;

            state_d             = ST_MEM_REQ;
          end
        end
        else begin
          pc_d    = next_pc_ctrl_valid ? next_pc_ctrl : next_pc_seq;
          state_d = ST_FETCH_REQ;
        end
      end

      ST_MEM_REQ: begin
        if (mem_is_load_q) begin
          if (!mem_ar_done_q && axi_arvalid && axi_arready) begin
            mem_ar_done_d = 1'b1;
          end

          if (mem_ar_done_q || (axi_arvalid && axi_arready)) begin
            mem_ar_done_d = 1'b0;
            state_d       = ST_MEM_WAIT;
          end
        end
        else if (mem_is_store_q) begin
          if (!mem_aw_done_q && axi_awvalid && axi_awready) begin
            mem_aw_done_d = 1'b1;
          end

          if (!mem_w_done_q && axi_wvalid && axi_wready) begin
            mem_w_done_d = 1'b1;
          end

          if ((mem_aw_done_q || (axi_awvalid && axi_awready)) &&
              (mem_w_done_q  || (axi_wvalid  && axi_wready))) begin
            mem_aw_done_d = 1'b0;
            mem_w_done_d  = 1'b0;
            state_d       = ST_MEM_WAIT;
          end
        end
      end

      ST_MEM_WAIT: begin
        if (mem_is_load_q && axi_rvalid) begin
          if (axi_rresp != AXI_RESP_OKAY) begin
            illegal_d = 1'b1;
            state_d   = ST_HALT;
          end
          else begin
            pc_d    = next_pc_seq;
            state_d = ST_FETCH_REQ;                       // MEM-011, MEM-013
          end
        end
        else if (mem_is_store_q && axi_bvalid) begin
          if (axi_bresp != AXI_RESP_OKAY) begin
            illegal_d = 1'b1;
            state_d   = ST_HALT;
          end
          else begin
            pc_d    = next_pc_seq;                        // MEM-010, MEM-013
            state_d = ST_FETCH_REQ;
          end
        end
      end

      ST_HALT: begin
        illegal_d = 1'b1;                                 // EXC-002
        state_d   = ST_HALT;
      end

      default: begin
        illegal_d = 1'b1;
        state_d   = ST_HALT;
      end
    endcase
  end

  //============================================================
  // AXI outputs
  //============================================================

  always_comb begin
    axi_awvalid = 1'b0;
    axi_awaddr  = 32'h0000_0000;
    axi_awprot  = 3'b000;

    axi_wvalid  = 1'b0;
    axi_wdata   = mem_wdata_q;
    axi_wstrb   = mem_wstrb_q;

    axi_bready  = 1'b0;

    axi_arvalid = 1'b0;
    axi_araddr  = 32'h0000_0000;
    axi_arprot  = 3'b000;

    axi_rready  = 1'b0;

    if (rst_n) begin

      unique case (state_q)

        ST_FETCH_REQ: begin
          axi_arvalid = !fetch_ar_done_q;
          axi_araddr  = pc_q;                             // IF-007
          axi_arprot  = 3'b100;                           // instruction access
        end

        ST_FETCH_WAIT: begin
          axi_rready  = 1'b1;
        end

        ST_MEM_REQ: begin
          if (mem_is_load_q) begin
            axi_arvalid = !mem_ar_done_q;
            axi_araddr  = mem_addr_q;
            axi_arprot  = 3'b000;                         // MEM-014
          end
          else if (mem_is_store_q) begin
            axi_awvalid = !mem_aw_done_q;
            axi_awaddr  = mem_addr_q;
            axi_awprot  = 3'b000;                         // MEM-014

            axi_wvalid  = !mem_w_done_q;
          end
        end

        ST_MEM_WAIT: begin
          if (mem_is_load_q) begin
            axi_rready = 1'b1;
          end
          else if (mem_is_store_q) begin
            axi_bready = 1'b1;
          end
        end

        default: begin
        end
      endcase

    end // if (rst_n)
  end

endmodule
