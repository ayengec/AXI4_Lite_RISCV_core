// cpu_address_boundary_seq.sv
// Author: Alican Yengec
// Purpose: Directed address boundary program for implemented 32-bit memory window.

class cpu_address_boundary_seq extends cpu_base_seq;
  `uvm_object_utils(cpu_address_boundary_seq)

  function new(string name = "cpu_address_boundary_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Building address-boundary program", UVM_LOW)
    clear_program();

    add_instr(addi(5'd1, 5'd0, 12'h3fc),
              "ADDRESS BOUNDARY: x1 = 0x000003fc, top implemented RAM word address");
    add_instr(addi(5'd2, 5'd0, 12'h05a),
              "SETUP: x2 = 0x0000005a");
    add_instr(sw(5'd2, 5'd1, 12'h000),
              "BOUNDARY STORE: MEM[0x000003fc] = x2");
    add_instr(lw(5'd3, 5'd1, 12'h000),
              "BOUNDARY LOAD: x3 = MEM[0x000003fc], expect 0x0000005a");
    add_instr(addi(5'd4, 5'd0, 12'h200),
              "SETUP: x4 = scoreboard checkpoint base 0x00000200");
    add_instr(sw(5'd3, 5'd4, 12'h000),
              "CHECKPOINT: MEM[0x00000200] = x3, expect 0x0000005a");
    add_instr(illegal_instr(),
              "HALT: illegal instruction 0x00000000 stops CPU");

    `uvm_info(get_type_name(), $sformatf("Address-boundary program: %0d instructions", program_size), UVM_LOW)
  endtask
endclass : cpu_address_boundary_seq
