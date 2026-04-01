`timescale 1ns/1ps

module tb_rv32i_regfile_sanity;

  logic        clk;
  logic        rst_n;

  logic        we_i;
  logic [4:0]  waddr_i;
  logic [31:0] wdata_i;

  logic [4:0]  raddr1_i;
  logic [31:0] rdata1_o;

  logic [4:0]  raddr2_i;
  logic [31:0] rdata2_o;

  integer pass_count;
  integer fail_count;

  rv32i_regfile dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .we_i    (we_i),
    .waddr_i (waddr_i),
    .wdata_i (wdata_i),
    .raddr1_i(raddr1_i),
    .rdata1_o(rdata1_o),
    .raddr2_i(raddr2_i),
    .rdata2_o(rdata2_o)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task automatic check_equal;
    input [31:0] actual;
    input [31:0] expected;
    input [1023:0] msg;
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

  task automatic write_reg;
    input [4:0]  addr;
    input [31:0] data;
    begin
      we_i    = 1'b1;
      waddr_i = addr;
      wdata_i = data;
      @(posedge clk);
      #1;
      we_i    = 1'b0;
      waddr_i = 5'd0;
      wdata_i = 32'h0000_0000;
    end
  endtask

  initial begin
    pass_count = 0;
    fail_count = 0;

    rst_n    = 1'b0;
    we_i     = 1'b0;
    waddr_i  = 5'd0;
    wdata_i  = 32'h0000_0000;
    raddr1_i = 5'd0;
    raddr2_i = 5'd0;

    $display("==============================================");
    $display("Starting tb_rv32i_regfile_sanity sanity test");
    $display("==============================================");

    @(posedge clk);
    #1;

    raddr1_i = 5'd0;
    raddr2_i = 5'd1;
    #1;
    check_equal(rdata1_o, 32'h0000_0000, "RF-002: x0 shall be zero after reset");
    check_equal(rdata2_o, 32'h0000_0000, "RF-003: x1 shall be zero after reset");

    raddr1_i = 5'd15;
    raddr2_i = 5'd31;
    #1;
    check_equal(rdata1_o, 32'h0000_0000, "RF-003: x15 shall be zero after reset");
    check_equal(rdata2_o, 32'h0000_0000, "RF-003: x31 shall be zero after reset");

    rst_n = 1'b1;
    @(posedge clk);
    #1;

    write_reg(5'd5, 32'hA5A5_1234);
    raddr1_i = 5'd5;
    #1;
    check_equal(rdata1_o, 32'hA5A5_1234, "RF-004/RF-005: x5 write then async read");

    write_reg(5'd10, 32'h1111_2222);
    write_reg(5'd11, 32'h3333_4444);

    raddr1_i = 5'd10;
    raddr2_i = 5'd11;
    #1;
    check_equal(rdata1_o, 32'h1111_2222, "RF-006: port1 reads x10");
    check_equal(rdata2_o, 32'h3333_4444, "RF-006: port2 reads x11");

    write_reg(5'd0, 32'hFFFF_FFFF);
    raddr1_i = 5'd0;
    #1;
    check_equal(rdata1_o, 32'h0000_0000, "RF-002: write to x0 shall be discarded");

    raddr1_i = 5'd7;
    raddr2_i = 5'd7;
    we_i     = 1'b1;
    waddr_i  = 5'd7;
    wdata_i  = 32'hDEAD_BEEF;
    #1;

    check_equal(rdata1_o, 32'hDEAD_BEEF, "RF-008: port1 bypass on same-cycle read/write");
    check_equal(rdata2_o, 32'hDEAD_BEEF, "RF-008: port2 bypass on same-cycle read/write");

    @(posedge clk);
    #1;
    we_i    = 1'b0;
    waddr_i = 5'd0;
    wdata_i = 32'h0000_0000;

    raddr1_i = 5'd7;
    #1;
    check_equal(rdata1_o, 32'hDEAD_BEEF, "RF-008: x7 stored after clock edge");

    raddr1_i = 5'd10;
    #1;
    check_equal(rdata1_o, 32'h1111_2222, "RF-005: port1 async read x10");

    raddr1_i = 5'd11;
    #1;
    check_equal(rdata1_o, 32'h3333_4444, "RF-005: port1 async read x11");

    $display("==============================================");
    $display("Sanity test finished | PASS=%0d FAIL=%0d", pass_count, fail_count);
    $display("==============================================");

    if (fail_count != 0) begin
      $fatal;
    end

    $finish;
  end
  
  initial begin
  $dumpfile("dump.vcd");
  $dumpvars(0, tb_rv32i_regfile_sanity);
 end

endmodule
