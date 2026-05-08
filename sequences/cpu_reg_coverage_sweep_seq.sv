// cpu_reg_coverage_sweep_seq.sv
// Author: Alican Yengec
// Purpose: Coverage-directed register/opcode sweep for functional coverage closure.

class cpu_reg_coverage_sweep_seq extends cpu_base_seq;
  `uvm_object_utils(cpu_reg_coverage_sweep_seq)

  function new(string name = "cpu_reg_coverage_sweep_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Building register coverage sweep program", UVM_LOW)
    clear_program();

    add_instr(addi(5'd1, 5'd0, 12'h200),
              "SETUP: ADDI x1 = x0 + 0x200 -> data base 0x00000200");

    add_instr(addi(5'd7,  5'd0, 12'd7),  "COV SETUP: ADDI x7  = 7");
    add_instr(addi(5'd8,  5'd0, 12'd8),  "COV SETUP: ADDI x8  = 8");
    add_instr(addi(5'd9,  5'd0, 12'd9),  "COV SETUP: ADDI x9  = 9");
    add_instr(addi(5'd12, 5'd0, 12'd12), "COV SETUP: ADDI x12 = 12");
    add_instr(addi(5'd13, 5'd0, 12'd13), "COV SETUP: ADDI x13 = 13");
    add_instr(addi(5'd14, 5'd0, 12'd14), "COV SETUP: ADDI x14 = 14");
    add_instr(addi(5'd15, 5'd0, 12'd15), "COV SETUP: ADDI x15 = 15");
    add_instr(addi(5'd17, 5'd0, 12'd17), "COV SETUP: ADDI x17 = 17");
    add_instr(addi(5'd20, 5'd0, 12'd20), "COV SETUP: ADDI x20 = 20");
    add_instr(addi(5'd21, 5'd0, 12'd21), "COV SETUP: ADDI x21 = 21");
    add_instr(addi(5'd25, 5'd0, 12'd25), "COV SETUP: ADDI x25 = 25");
    add_instr(addi(5'd26, 5'd0, 12'd26), "COV SETUP: ADDI x26 = 26 -> covers missing rd and rs2 source");
    add_instr(addi(5'd28, 5'd0, 12'd28), "COV SETUP: ADDI x28 = 28");
    add_instr(addi(5'd29, 5'd0, 12'd29), "COV SETUP: ADDI x29 = 29 -> covers missing rd");
    add_instr(addi(5'd30, 5'd0, 12'd30), "COV SETUP: ADDI x30 = 30 -> covers missing rd, rs1, and rs2 source");
    add_instr(addi(5'd31, 5'd0, 12'd31), "COV SETUP: ADDI x31 = 31");

    add_instr(add(5'd2,  5'd7,  5'd26), "COV RS: ADD x2  = x7  + x26 -> hits rs1=x7,  rs2=x26");
    add_instr(add(5'd3,  5'd8,  5'd30), "COV RS: ADD x3  = x8  + x30 -> hits rs1=x8,  rs2=x30");
    add_instr(add(5'd4,  5'd9,  5'd26), "COV RS: ADD x4  = x9  + x26 -> hits rs1=x9");
    add_instr(add(5'd5,  5'd12, 5'd30), "COV RS: ADD x5  = x12 + x30 -> hits rs1=x12");
    add_instr(add(5'd6,  5'd13, 5'd26), "COV RS: ADD x6  = x13 + x26 -> hits rs1=x13");
    add_instr(add(5'd10, 5'd14, 5'd30), "COV RS: ADD x10 = x14 + x30 -> hits rs1=x14");
    add_instr(add(5'd11, 5'd15, 5'd26), "COV RS: ADD x11 = x15 + x26 -> hits rs1=x15");
    add_instr(add(5'd16, 5'd17, 5'd30), "COV RS: ADD x16 = x17 + x30 -> hits rs1=x17");
    add_instr(add(5'd18, 5'd20, 5'd26), "COV RS: ADD x18 = x20 + x26 -> hits rs1=x20");
    add_instr(add(5'd19, 5'd21, 5'd30), "COV RS: ADD x19 = x21 + x30 -> hits rs1=x21");
    add_instr(add(5'd22, 5'd25, 5'd26), "COV RS: ADD x22 = x25 + x26 -> hits rs1=x25");
    add_instr(add(5'd23, 5'd28, 5'd30), "COV RS: ADD x23 = x28 + x30 -> hits rs1=x28");
    add_instr(add(5'd24, 5'd30, 5'd26), "COV RS: ADD x24 = x30 + x26 -> hits rs1=x30");
    add_instr(add(5'd27, 5'd31, 5'd30), "COV RS: ADD x27 = x31 + x30 -> hits rs1=x31");

    add_instr(add(5'd5,  5'd10, 5'd26), "COV RS1: ADD x5  = x10 + x26 -> hits rs1=x10");
    add_instr(add(5'd6,  5'd16, 5'd30), "COV RS1: ADD x6  = x16 + x30 -> hits rs1=x16");
    add_instr(add(5'd11, 5'd19, 5'd26), "COV RS1: ADD x11 = x19 + x26 -> hits rs1=x19");
    add_instr(add(5'd12, 5'd23, 5'd30), "COV RS1: ADD x12 = x23 + x30 -> hits rs1=x23");
    add_instr(add(5'd13, 5'd24, 5'd26), "COV RS1: ADD x13 = x24 + x26 -> hits rs1=x24");
    add_instr(add(5'd14, 5'd29, 5'd30), "COV RS1: ADD x14 = x29 + x30 -> hits rs1=x29");
    add_instr(add(5'd15, 5'd6,  5'd26), "COV RS1: ADD x15 = x6  + x26 -> hits rs1=x6");
    add_instr(add(5'd17, 5'd18, 5'd30), "COV RS1: ADD x17 = x18 + x30 -> hits rs1=x18");

    add_instr(sw(5'd2,  5'd1, 12'h000),
              "CHECKPOINT: SW x2  -> MEM[0x200], expect 0x00000021");
    add_instr(sw(5'd3,  5'd1, 12'h004),
              "CHECKPOINT: SW x3  -> MEM[0x204], expect 0x00000026");
    add_instr(sw(5'd24, 5'd1, 12'h008),
              "CHECKPOINT: SW x24 -> MEM[0x208], expect 0x00000038");
    add_instr(sw(5'd27, 5'd1, 12'h00c),
              "CHECKPOINT: SW x27 -> MEM[0x20c], expect 0x0000003d");

    add_instr(32'h00000073,
              "HALT/COVERAGE: ECALL hits SYSTEM opcode bin and stops CPU");

    `uvm_info(get_type_name(), $sformatf("Register coverage sweep program: %0d instructions", program_size), UVM_LOW)
  endtask
endclass : cpu_reg_coverage_sweep_seq
