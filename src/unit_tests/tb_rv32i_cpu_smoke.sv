`timescale 1ns/1ps

import rv32i_pkg::*;

module tb_rv32i_cpu_smoke;

  logic        clk;
  logic        rst_n;
  logic        illegal_instr;

  logic        axi_awvalid;
  logic        axi_awready;
  logic [31:0] axi_awaddr;
  logic [2:0]  axi_awprot;

  logic        axi_wvalid;
  logic        axi_wready;
  logic [31:0] axi_wdata;
  logic [3:0]  axi_wstrb;

  logic        axi_bvalid;
  logic        axi_bready;
  logic [1:0]  axi_bresp;

  logic        axi_arvalid;
  logic        axi_arready;
  logic [31:0] axi_araddr;
  logic [2:0]  axi_arprot;

  logic        axi_rvalid;
  logic        axi_rready;
  logic [31:0] axi_rdata;
  logic [1:0]  axi_rresp;

  integer pass_count;
  integer fail_count;

  logic [31:0] mem [0:63];

  logic [31:0] pending_raddr;
  logic        pending_rvalid;
  logic [31:0] pending_awaddr;
  logic        have_aw;
  logic        have_w;
  logic [31:0] pending_wdata;
  logic [3:0]  pending_wstrb;
  logic        pending_bvalid;

  rv32i_cpu dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .illegal_instr(illegal_instr),

    .axi_awvalid  (axi_awvalid),
    .axi_awready  (axi_awready),
    .axi_awaddr   (axi_awaddr),
    .axi_awprot   (axi_awprot),

    .axi_wvalid   (axi_wvalid),
    .axi_wready   (axi_wready),
    .axi_wdata    (axi_wdata),
    .axi_wstrb    (axi_wstrb),

    .axi_bvalid   (axi_bvalid),
    .axi_bready   (axi_bready),
    .axi_bresp    (axi_bresp),

    .axi_arvalid  (axi_arvalid),
    .axi_arready  (axi_arready),
    .axi_araddr   (axi_araddr),
    .axi_arprot   (axi_arprot),

    .axi_rvalid   (axi_rvalid),
    .axi_rready   (axi_rready),
    .axi_rdata    (axi_rdata),
    .axi_rresp    (axi_rresp)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task automatic check_u32;
    input logic [31:0] actual;
    input logic [31:0] expected;
    input [1023:0]     msg;
    begin
      if (actual !== expected) begin
        fail_count = fail_count + 1;
        $display("[FAIL] %0s | expected=0x%08h actual=0x%08h", msg, expected, actual);
      end
      else begin
        pass_count = pass_count + 1;
        $display("[PASS] %0s", msg);
      end
    end
  endtask

  task automatic check_bit;
    input logic actual;
    input logic expected;
    input [1023:0] msg;
    begin
      if (actual !== expected) begin
        fail_count = fail_count + 1;
        $display("[FAIL] %0s | expected=%0b actual=%0b", msg, expected, actual);
      end
      else begin
        pass_count = pass_count + 1;
        $display("[PASS] %0s", msg);
      end
    end
  endtask

  function automatic [31:0] encode_addi;
    input [4:0] rd;
    input [4:0] rs1;
    input integer imm;
    logic [11:0] imm12;
    begin
      imm12 = imm[11:0];
      encode_addi = {imm12, rs1, 3'b000, rd, 7'b0010011};
    end
  endfunction

  function automatic [31:0] encode_add;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] rs2;
    begin
      encode_add = {7'b0000000, rs2, rs1, 3'b000, rd, 7'b0110011};
    end
  endfunction

  function automatic [31:0] encode_lw;
    input [4:0] rd;
    input [4:0] rs1;
    input integer imm;
    logic [11:0] imm12;
    begin
      imm12 = imm[11:0];
      encode_lw = {imm12, rs1, 3'b010, rd, 7'b0000011};
    end
  endfunction

  function automatic [31:0] encode_sw;
    input [4:0] rs2;
    input [4:0] rs1;
    input integer imm;
    logic [11:0] imm12;
    begin
      imm12 = imm[11:0];
      encode_sw = {imm12[11:5], rs2, rs1, 3'b010, imm12[4:0], 7'b0100011};
    end
  endfunction

  function automatic [31:0] encode_beq;
    input [4:0] rs1;
    input [4:0] rs2;
    input integer imm;
    logic [12:0] bimm;
    begin
      bimm = imm[12:0];
      encode_beq = {
        bimm[12],
        bimm[10:5],
        rs2,
        rs1,
        3'b000,
        bimm[4:1],
        bimm[11],
        7'b1100011
      };
    end
  endfunction

  task automatic write_word_strb;
    input logic [31:0] addr;
    input logic [31:0] data;
    input logic [3:0]  strb;
    integer idx;
    logic [31:0] tmp;
    begin
      idx = addr[31:2];
      tmp = mem[idx];
      if (strb[0]) tmp[7:0]   = data[7:0];
      if (strb[1]) tmp[15:8]  = data[15:8];
      if (strb[2]) tmp[23:16] = data[23:16];
      if (strb[3]) tmp[31:24] = data[31:24];
      mem[idx] = tmp;
    end
  endtask

  assign axi_awready = 1'b1;
  assign axi_wready  = 1'b1;
  assign axi_arready = 1'b1;
  assign axi_bresp   = AXI_RESP_OKAY;
  assign axi_rresp   = AXI_RESP_OKAY;

  assign axi_bvalid  = pending_bvalid;
  assign axi_rvalid  = pending_rvalid;
  assign axi_rdata   = mem[pending_raddr[31:2]];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pending_raddr  <= 32'h0000_0000;
      pending_rvalid <= 1'b0;

      pending_awaddr <= 32'h0000_0000;
      have_aw        <= 1'b0;
      have_w         <= 1'b0;
      pending_wdata  <= 32'h0000_0000;
      pending_wstrb  <= 4'b0000;
      pending_bvalid <= 1'b0;
    end
    else begin
      if (axi_arvalid && axi_arready) begin
        pending_raddr  <= axi_araddr;
        pending_rvalid <= 1'b1;
      end
      else if (pending_rvalid && axi_rready) begin
        pending_rvalid <= 1'b0;
      end

      if (axi_awvalid && axi_awready) begin
        pending_awaddr <= axi_awaddr;
        have_aw        <= 1'b1;
      end

      if (axi_wvalid && axi_wready) begin
        pending_wdata <= axi_wdata;
        pending_wstrb <= axi_wstrb;
        have_w        <= 1'b1;
      end

      if (have_aw && have_w && !pending_bvalid) begin
        write_word_strb(pending_awaddr, pending_wdata, pending_wstrb);
        pending_bvalid <= 1'b1;
        have_aw        <= 1'b0;
        have_w         <= 1'b0;
      end
      else if (pending_bvalid && axi_bready) begin
        pending_bvalid <= 1'b0;
      end
    end
  end

  integer i;
  initial begin
    for (i = 0; i < 64; i = i + 1) begin
      mem[i] = 32'h0000_0000;
    end

    mem[0] = encode_addi(5'd1, 5'd0, 5);
    mem[1] = encode_addi(5'd2, 5'd0, 7);
    mem[2] = encode_add (5'd3, 5'd1, 5'd2);
    mem[3] = encode_sw  (5'd3, 5'd0, 0);
    mem[4] = encode_lw  (5'd4, 5'd0, 0);
    mem[5] = encode_beq (5'd3, 5'd4, 8);
    mem[6] = encode_addi(5'd5, 5'd0, 1);
    mem[7] = encode_addi(5'd6, 5'd0, 9);
    mem[8] = 32'hFFFF_FFFF;
  end

  initial begin
    integer cyc;

    pass_count = 0;
    fail_count = 0;

    rst_n = 1'b0;

    $display("==============================================");
    $display("Starting tb_rv32i_cpu_smoke");
    $display("==============================================");

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (cyc = 0; cyc < 100; cyc = cyc + 1) begin
      @(posedge clk);
      if (illegal_instr)
        break;
    end

    #1;

    check_u32(dut.u_regfile.regs[3], 32'h0000_000C, "CPU smoke: x3 = x1 + x2 = 12");
    check_u32(dut.u_regfile.regs[4], 32'h0000_000C, "CPU smoke: x4 loaded from memory");
    check_u32(dut.u_regfile.regs[5], 32'h0000_0000, "CPU smoke: x5 skipped by BEQ");
    check_u32(dut.u_regfile.regs[6], 32'h0000_0009, "CPU smoke: x6 executed after branch target");
    check_u32(mem[0],               32'h0000_000C, "CPU smoke: memory[0] written by SW");
    check_bit(illegal_instr,        1'b1,          "CPU smoke: illegal instruction halts CPU");

    $display("==============================================");
    $display("CPU smoke finished | PASS=%0d FAIL=%0d", pass_count, fail_count);
    $display("==============================================");

    if (fail_count != 0) begin
      $fatal;
    end

    $finish;
  end

    initial begin
      $dumpfile("dump.vcd");
      $dumpvars(0, tb_rv32i_cpu_smoke);
    end

endmodule
