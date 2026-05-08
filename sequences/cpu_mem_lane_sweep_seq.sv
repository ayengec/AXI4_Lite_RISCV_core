// cpu_mem_lane_sweep_seq.sv
// Author: Alican Yengec
// Purpose: Directed byte/halfword lane sweep for memory datapath code coverage.

class cpu_mem_lane_sweep_seq extends cpu_base_seq;
  `uvm_object_utils(cpu_mem_lane_sweep_seq)

  function new(string name = "cpu_mem_lane_sweep_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Building memory lane sweep program", UVM_LOW)
    clear_program();

    add_instr(addi(5'd1, 5'd0, 12'h200),
              "SETUP: ADDI x1 = x0 + 0x200 -> data base 0x00000200");

    add_instr(sw(5'd0, 5'd1, 12'h000),
              "SETUP: clear MEM[0x200] before byte lane sweep");
    add_instr(addi(5'd2, 5'd0, 12'h011),
              "SETUP: x2 = 0x11 for SB lane 1");
    add_instr(addi(5'd3, 5'd0, 12'h022),
              "SETUP: x3 = 0x22 for SB lane 2");
    add_instr(addi(5'd4, 5'd0, 12'h0f0),
              "SETUP: x4 = 0xf0 for SB lane 3 and signed LB");

    add_instr(rv_s_type(12'h001, 5'd2, 5'd1, 3'b000, 7'b0100011),
              "SB: store x2[7:0] -> MEM[0x201], expect byte lane 1");
    add_instr(rv_s_type(12'h002, 5'd3, 5'd1, 3'b000, 7'b0100011),
              "SB: store x3[7:0] -> MEM[0x202], expect byte lane 2");
    add_instr(rv_s_type(12'h003, 5'd4, 5'd1, 3'b000, 7'b0100011),
              "SB: store x4[7:0] -> MEM[0x203], expect byte lane 3");

    add_instr(lw(5'd5, 5'd1, 12'h000),
              "LW: x5 = MEM[0x200], expect 0xf0221100");
    add_instr(sw(5'd5, 5'd1, 12'h004),
              "CHECKPOINT: SW x5 -> MEM[0x204], expect 0xf0221100");

    add_instr(rv_i_type(12'h001, 5'd1, 3'b000, 5'd6, 7'b0000011),
              "LB: x6 = signed byte MEM[0x201], expect 0x00000011");
    add_instr(rv_i_type(12'h002, 5'd1, 3'b100, 5'd7, 7'b0000011),
              "LBU: x7 = unsigned byte MEM[0x202], expect 0x00000022");
    add_instr(rv_i_type(12'h003, 5'd1, 3'b000, 5'd8, 7'b0000011),
              "LB: x8 = signed byte MEM[0x203], expect 0xfffffff0");
    add_instr(sw(5'd6, 5'd1, 12'h008),
              "CHECKPOINT: SW x6 -> MEM[0x208], expect 0x00000011");
    add_instr(sw(5'd7, 5'd1, 12'h00c),
              "CHECKPOINT: SW x7 -> MEM[0x20c], expect 0x00000022");
    add_instr(sw(5'd8, 5'd1, 12'h010),
              "CHECKPOINT: SW x8 -> MEM[0x210], expect 0xfffffff0");

    add_instr(sw(5'd0, 5'd1, 12'h014),
              "SETUP: clear MEM[0x214] before upper-halfword sweep");
    add_instr(addi(5'd9, 5'd0, 12'h7f0),
              "SETUP: x9 = 0x7f0 for SH upper-halfword lane");
    add_instr(rv_s_type(12'h016, 5'd9, 5'd1, 3'b001, 7'b0100011),
              "SH: store x9[15:0] -> MEM[0x216], expect upper halfword");
    add_instr(rv_i_type(12'h016, 5'd1, 3'b001, 5'd10, 7'b0000011),
              "LH: x10 = signed halfword MEM[0x216], expect 0x000007f0");
    add_instr(rv_i_type(12'h016, 5'd1, 3'b101, 5'd11, 7'b0000011),
              "LHU: x11 = unsigned halfword MEM[0x216], expect 0x000007f0");
    add_instr(sw(5'd10, 5'd1, 12'h018),
              "CHECKPOINT: SW x10 -> MEM[0x218], expect 0x000007f0");
    add_instr(sw(5'd11, 5'd1, 12'h01c),
              "CHECKPOINT: SW x11 -> MEM[0x21c], expect 0x000007f0");

    add_instr(illegal_instr(),
              "HALT: illegal instruction 0x00000000 stops CPU");

    `uvm_info(get_type_name(), $sformatf("Memory lane sweep program: %0d instructions", program_size), UVM_LOW)
  endtask
endclass : cpu_mem_lane_sweep_seq
