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

  logic [31:0] latched_awaddr;
  logic [31:0] latched_wdata;
  logic [3:0]  latched_wstrb;
  logic        have_aw;
  logic        have_w;

  rv32i_cpu dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .illegal_instr (illegal_instr),

    .axi_awvalid   (axi_awvalid),
    .axi_awready   (axi_awready),
    .axi_awaddr    (axi_awaddr),
    .axi_awprot    (axi_awprot),

    .axi_wvalid    (axi_wvalid),
    .axi_wready    (axi_wready),
    .axi_wdata     (axi_wdata),
    .axi_wstrb     (axi_wstrb),

    .axi_bvalid    (axi_bvalid),
    .axi_bready    (axi_bready),
    .axi_bresp     (axi_bresp),

    .axi_arvalid   (axi_arvalid),
    .axi_arready   (axi_arready),
    .axi_araddr    (axi_araddr),
    .axi_arprot    (axi_arprot),

    .axi_rvalid    (axi_rvalid),
    .axi_rready    (axi_rready),
    .axi_rdata     (axi_rdata),
    .axi_rresp     (axi_rresp)
  );

  // ------------------------------------------------------------
  // Clock
  // ------------------------------------------------------------
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------
  task automatic check_u32;
    input logic [31:0] actual;
    input logic [31:0] expected;
    input [1023:0] msg;
    begin
      if (actual !== expected) begin
        fail_count = fail_count + 1;
        $display("[FAIL] %0s | expected=0x%08h actual=0x%08h", msg, expected, actual);
      end else begin
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
      end else begin
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



  function automatic [8*24-1:0] state_name;
    input logic [2:0] state;
    begin
      case (state)
        3'd0: state_name = "FETCH_REQ";
        3'd1: state_name = "FETCH_WAIT";
        3'd2: state_name = "EXECUTE";
        3'd3: state_name = "MEM_REQ";
        3'd4: state_name = "MEM_WAIT";
        3'd5: state_name = "HALT";
        default: state_name = "UNKNOWN";
      endcase
    end
  endfunction

  function automatic [8*96-1:0] program_step_desc;
    input logic [31:0] addr;
    begin
      case (addr)
        32'h0000_0000: program_step_desc = "Step 1: ADDI x1, x0, 5    -> initialize x1 with 5";
        32'h0000_0004: program_step_desc = "Step 2: ADDI x2, x0, 7    -> initialize x2 with 7";
        32'h0000_0008: program_step_desc = "Step 3: ADD  x3, x1, x2   -> x3 should become 12";
        32'h0000_000C: program_step_desc = "Step 4: SW   x3, 64(x0)   -> store result to memory[16]";
        32'h0000_0010: program_step_desc = "Step 5: LW   x4, 64(x0)   -> load stored value back into x4";
        32'h0000_0014: program_step_desc = "Step 6: BEQ  x3, x4, +8   -> branch should be taken";
        32'h0000_0018: program_step_desc = "Step 7: ADDI x5, x0, 1    -> must be skipped if BEQ works";
        32'h0000_001C: program_step_desc = "Step 8: ADDI x6, x0, 9    -> executes after taken branch";
        32'h0000_0020: program_step_desc = "Step 9: ILLEGAL           -> CPU must assert illegal and halt";
        default:      program_step_desc = "Program step: unknown address";
      endcase
    end
  endfunction


  function automatic [8*20-1:0] wb_target_name;
    input logic [4:0] rd;
    begin
      case (rd)
        5'd1: wb_target_name = "x1";
        5'd2: wb_target_name = "x2";
        5'd3: wb_target_name = "x3";
        5'd4: wb_target_name = "x4";
        5'd5: wb_target_name = "x5";
        5'd6: wb_target_name = "x6";
        default: wb_target_name = "rd";
      endcase
    end
  endfunction

  function automatic [8*96-1:0] wb_desc;
    input logic [31:0] pc;
    input logic [4:0]  rd;
    begin
      case (pc)
        32'h0000_0000: wb_desc = "Step 1 completed: x1 receives constant 5";
        32'h0000_0004: wb_desc = "Step 2 completed: x2 receives constant 7";
        32'h0000_0008: wb_desc = "Step 3 completed: x3 receives the sum x1 + x2";
        32'h0000_0010: wb_desc = "Step 5 completed: x4 receives the value loaded from memory[16]";
        32'h0000_0018: wb_desc = "Step 7 completed unexpectedly: skipped instruction wrote x5";
        32'h0000_001C: wb_desc = "Step 8 completed: x6 receives constant 9 at the branch target";
        default: begin
          case (rd)
            5'd1: wb_desc = "Register writeback observed on x1";
            5'd2: wb_desc = "Register writeback observed on x2";
            5'd3: wb_desc = "Register writeback observed on x3";
            5'd4: wb_desc = "Register writeback observed on x4";
            5'd5: wb_desc = "Register writeback observed on x5";
            5'd6: wb_desc = "Register writeback observed on x6";
            default: wb_desc = "Register writeback observed";
          endcase
        end
      endcase
    end
  endfunction

  task automatic log_test_plan;
    begin
      $display("Test intent by program step:");
      $display("  Step 1) Build constant 5 in x1");
      $display("  Step 2) Build constant 7 in x2");
      $display("  Step 3) Add x1 and x2 into x3");
      $display("  Step 4) Store x3 to memory[16]");
      $display("  Step 5) Load memory[16] back into x4");
      $display("  Step 6) Take BEQ because x3 == x4");
      $display("  Step 7) Intentionally skip ADDI x5, x0, 1 because the branch is taken");
      $display("  Step 8) Execute the branch target and write x6 = 9");
      $display("  Step 9) Execute an illegal instruction and halt the CPU");
    end
  endtask

  task automatic log_register_snapshot;
    begin
      $display("Final architectural state snapshot:");
      $display("  x1 = 0x%08h", dut.u_regfile.regs[1]);
      $display("  x2 = 0x%08h", dut.u_regfile.regs[2]);
      $display("  x3 = 0x%08h", dut.u_regfile.regs[3]);
      $display("  x4 = 0x%08h", dut.u_regfile.regs[4]);
      $display("  x5 = 0x%08h", dut.u_regfile.regs[5]);
      $display("  x6 = 0x%08h", dut.u_regfile.regs[6]);
      $display("  mem[16] = 0x%08h", mem[16]);
      $display("  illegal_instr = %0b", illegal_instr);
    end
  endtask

  // ------------------------------------------------------------
  // Program load
  // ------------------------------------------------------------
  integer i;
  initial begin
    for (i = 0; i < 64; i = i + 1)
      mem[i] = 32'h0000_0000;

    mem[0] = encode_addi(5'd1, 5'd0, 5);     // x1 = 5
    mem[1] = encode_addi(5'd2, 5'd0, 7);     // x2 = 7
    mem[2] = encode_add (5'd3, 5'd1, 5'd2);  // x3 = 12
    mem[3] = encode_sw  (5'd3, 5'd0, 64);    // mem[16] = x3
    mem[4] = encode_lw  (5'd4, 5'd0, 64);    // x4 = mem[16]
    mem[5] = encode_beq (5'd3, 5'd4, 8);     // skip next (offset=8 -> mem[7])
    mem[6] = encode_addi(5'd5, 5'd0, 1);     // skipped
    mem[7] = encode_addi(5'd6, 5'd0, 9);     // executes
    mem[8] = 32'hFFFF_FFFF;                  // illegal -> halt
  end

  // ------------------------------------------------------------
  // AXI slave static outputs (always ready)
  // ------------------------------------------------------------
  assign axi_awready = 1'b1;
  assign axi_wready  = 1'b1;
  assign axi_arready = 1'b1;
  assign axi_bresp   = AXI_RESP_OKAY;
  assign axi_rresp   = AXI_RESP_OKAY;

  // ------------------------------------------------------------
  // READ channel - clock synchronous AXI-Lite slave
  //
  // rvalid is asserted the cycle after the AR handshake and held
  // until the R handshake (rvalid && rready both high on posedge).
  // This guarantees the CPU always samples rvalid=1 cleanly.
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      axi_rvalid <= 1'b0;
      axi_rdata  <= 32'h0000_0000;
    end else begin
      // Clear rvalid once handshake completes
      if (axi_rvalid && axi_rready)
        axi_rvalid <= 1'b0;

      // Latch new read data on AR handshake (only when not already
      // serving a response, so we don't overwrite an in-flight rvalid)
      if (axi_arvalid && axi_arready && !(axi_rvalid && !axi_rready)) begin
        axi_rdata  <= mem[axi_araddr[31:2]];
        axi_rvalid <= 1'b1;
      end
    end
  end

  // ------------------------------------------------------------
  // WRITE channel - clock synchronous AXI-Lite slave
  //
  // AW and W channels are captured independently (they can arrive
  // in any order). Once both are captured, memory is written and
  // bvalid is asserted. bvalid is cleared after the B handshake.
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      axi_bvalid     <= 1'b0;
      have_aw        <= 1'b0;
      have_w         <= 1'b0;
      latched_awaddr <= 32'h0;
      latched_wdata  <= 32'h0;
      latched_wstrb  <= 4'h0;
    end else begin

      // Clear bvalid after B handshake
      if (axi_bvalid && axi_bready)
        axi_bvalid <= 1'b0;

      // Capture AW channel
      if (axi_awvalid && axi_awready && !have_aw) begin
        latched_awaddr <= axi_awaddr;
        have_aw        <= 1'b1;
      end

      // Capture W channel
      if (axi_wvalid && axi_wready && !have_w) begin
        latched_wdata <= axi_wdata;
        latched_wstrb <= axi_wstrb;
        have_w        <= 1'b1;
      end

      // Issue write + B response once both channels have been captured
      // and no B response is already in-flight
      if (have_aw && have_w && !axi_bvalid) begin
        // Apply byte strobes
        if (latched_wstrb[0]) mem[latched_awaddr[31:2]][7:0]   <= latched_wdata[7:0];
        if (latched_wstrb[1]) mem[latched_awaddr[31:2]][15:8]  <= latched_wdata[15:8];
        if (latched_wstrb[2]) mem[latched_awaddr[31:2]][23:16] <= latched_wdata[23:16];
        if (latched_wstrb[3]) mem[latched_awaddr[31:2]][31:24] <= latched_wdata[31:24];

        axi_bvalid <= 1'b1;
        have_aw    <= 1'b0;
        have_w     <= 1'b0;
      end
    end
  end

  // ------------------------------------------------------------
  // Human-readable execution monitors
  // ------------------------------------------------------------
  always @(posedge clk) begin
    if (rst_n) begin
      if (axi_arvalid && axi_arready) begin
        if (axi_arprot == 3'b100)
          $display("[IFETCH] PC=0x%08h | %0s | time=%0t", axi_araddr, program_step_desc(axi_araddr), $time);
        else
          $display("[DREAD-REQ ] addr=0x%08h | CPU requests load data | time=%0t", axi_araddr, $time);
      end

      if (axi_rvalid && axi_rready) begin
        if (dut.state_q == 3'd1)
          $display("[IFETCH-RSP] instr=0x%08h | instruction returned to CPU | time=%0t", axi_rdata, $time);
        else
          $display("[DREAD-RSP ] data=0x%08h | load data returned to CPU | time=%0t", axi_rdata, $time);
      end

      if (axi_awvalid && axi_awready)
        $display("[DWRITE-REQ] addr=0x%08h | CPU issues store address phase | time=%0t", axi_awaddr, $time);

      if (axi_wvalid && axi_wready)
        $display("[DWRITE-DAT] data=0x%08h strb=0x%0h | CPU issues store data phase | time=%0t", axi_wdata, axi_wstrb, $time);

      if (axi_bvalid && axi_bready) begin
        $display("[DWRITE-RSP] Store transaction completed successfully | time=%0t", $time);
        $display("[MEM] memory[%0d] <= 0x%08h | Step 4 completed: store committed to data memory", latched_awaddr[31:2], mem[latched_awaddr[31:2]]);
      end

      if (dut.rf_we)
        $display("[WB] %0s <= 0x%08h | %0s", wb_target_name(dut.rf_waddr), dut.rf_wdata, wb_desc(dut.pc_q, dut.rf_waddr));

      if (dut.state_q == 3'd2 && dut.dec_is_branch) begin
        if (dut.branch_taken)
          $display("[CTRL] BEQ taken | x3 == x4, PC will jump from 0x%08h to 0x%08h and Step 7 will be skipped", dut.pc_q, dut.branch_target);
        else
          $display("[CTRL] BEQ not taken | x3 != x4, execution will continue at PC+4");
      end
    end
  end

  // ------------------------------------------------------------
  // Test sequence
  // ------------------------------------------------------------
  initial begin
    integer cyc;

    pass_count = 0;
    fail_count = 0;
    rst_n      = 1'b0;

    $display("==============================================================");
    $display("Starting tb_rv32i_cpu_smoke");
    $display("Scenario: arithmetic -> store -> load -> taken branch -> skipped instruction -> halt");
    $display("==============================================================");
    log_test_plan();

    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    $display("[TB] Reset released. CPU should start fetching from PC=0x00000000.");

    for (cyc = 0; cyc < 120; cyc = cyc + 1) begin
      @(posedge clk);
      $display("[TRACE] cycle=%0d | state=%0s | pc=0x%08h | instr=0x%08h | illegal=%0b",
        cyc, state_name(dut.state_q), dut.pc_q, dut.instr_q, illegal_instr);

      if (dut.pc_q == 32'h0000_001C && dut.state_q == 3'd2) begin
        $display("[MILESTONE] Branch target reached. Step 7 (ADDI x5, x0, 1) was intentionally skipped.");
        $display("[MILESTONE] BEQ behavior confirmed. Execution continues with Step 8 at the branch target.");
      end

      if (illegal_instr) begin
        $display("[MILESTONE] Illegal instruction detected. CPU entered halt behavior as intended.");
        break;
      end
    end

    #2;

    $display("--------------------------------------------------------------");
    $display("Checking architectural results against the intended scenario");
    $display("--------------------------------------------------------------");

    check_u32(dut.u_regfile.regs[1], 32'h0000_0005,
      "Step 1 result: x1 must contain 5 after ADDI x1, x0, 5");
    check_u32(dut.u_regfile.regs[2], 32'h0000_0007,
      "Step 2 result: x2 must contain 7 after ADDI x2, x0, 7");
    check_u32(dut.u_regfile.regs[3], 32'h0000_000C,
      "Step 3 result: x3 must contain 12 after ADD x3, x1, x2");
    check_u32(mem[16], 32'h0000_000C,
      "Step 4 result: memory[16] must contain 12 after SW x3, 64(x0)");
    check_u32(dut.u_regfile.regs[4], 32'h0000_000C,
      "Step 5 result: x4 must load back 12 from memory[16]");

    if ((dut.u_regfile.regs[3] == dut.u_regfile.regs[4]) &&
        (dut.u_regfile.regs[5] == 32'h0000_0000) &&
        (dut.u_regfile.regs[6] == 32'h0000_0009)) begin
      pass_count++;
      $display("[PASS] Step 6 result: BEQ must be taken because x3 == x4, which skips Step 7 and transfers control to Step 8");
    end else begin
      fail_count++;
      $display("[FAIL] Step 6 result: BEQ should be taken when x3 == x4. Expected Step 7 to be skipped and Step 8 to execute | x3=0x%08x x4=0x%08x x5=0x%08x x6=0x%08x",
        dut.u_regfile.regs[3], dut.u_regfile.regs[4], dut.u_regfile.regs[5], dut.u_regfile.regs[6]);
    end

    check_u32(dut.u_regfile.regs[5], 32'h0000_0000,
      "Step 7 result: x5 must remain 0 because Step 7 is intentionally skipped by the taken BEQ");
    check_u32(dut.u_regfile.regs[6], 32'h0000_0009,
      "Step 8 result: x6 must contain 9 because the branch target instruction must execute");
    check_bit(illegal_instr, 1'b1,
      "Step 9 result: the illegal instruction must be detected and the CPU must halt");

    $display("--------------------------------------------------------------");
    log_register_snapshot();
    $display("--------------------------------------------------------------");
    $display("CPU smoke finished | PASS=%0d FAIL=%0d", pass_count, fail_count);
    $display("==============================================================");

    if (fail_count != 0) $fatal;

    $finish;
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_rv32i_cpu_smoke);
  end

endmodule