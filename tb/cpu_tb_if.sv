// cpu_tb_if.sv
// Testbench backdoor access layer for package-based UVM classes.

interface cpu_tb_if(input logic clk);

  task automatic release_reset();
    cpu_tb_top.release_reset();
  endtask

  task automatic assert_reset();
    cpu_tb_top.assert_reset();
  endtask

  task automatic preload_word(input logic [31:0] byte_addr,
                              input logic [31:0] data);
    cpu_tb_top.u_ram.preload_word(byte_addr, data);
  endtask

  function automatic logic [31:0] read_mem_word(input logic [31:0] byte_addr);
    return cpu_tb_top.u_ram.backdoor_read(byte_addr);
  endfunction

  function automatic logic [31:0] read_reg(input int unsigned idx);
    if (idx < 32)
      return cpu_tb_top.u_cpu.u_regfile.regs[idx];
    return 32'h0;
  endfunction

  function automatic bit illegal_instr();
    return (cpu_tb_top.u_cpu.illegal_instr === 1'b1);
  endfunction

  task automatic wait_illegal_instr();
    wait(cpu_tb_top.u_cpu.illegal_instr === 1'b1);
  endtask

  task automatic wait_clks(input int unsigned cycles);
    repeat(cycles) @(posedge clk);
  endtask

endinterface : cpu_tb_if
