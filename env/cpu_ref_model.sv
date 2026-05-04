// cpu_ref_model.sv
// Author: Alican Yengec
// Lightweight RV32I Instruction Set Simulator (ISS) for UVM scoreboard.
//
// Steps through a preloaded program instruction-by-instruction,
// maintaining expected register file state (x0-x31) and memory state.
// Produces expected final state for comparison with DUT.
//
// Supports: All RV32I base integer instructions
//   R-type: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
//   I-type: ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU
//   Load:   LW, LH, LB, LHU, LBU
//   Store:  SW, SH, SB
//   Branch: BEQ, BNE, BLT, BGE, BLTU, BGEU
//   Jump:   JAL, JALR
//   Upper:  LUI, AUIPC
//   System: Illegal -> halt

class cpu_ref_model extends uvm_component;
  `uvm_component_utils(cpu_ref_model)

  // Architectural state
  logic [31:0] regs   [32];     // x0-x31
  logic [31:0] memory [int];    // sparse memory model (byte_addr >> 2 -> word)
  logic [31:0] pc;
  bit          halted;
  int          instr_count;
  int          max_instructions;

  // Analysis port for functional coverage
  uvm_analysis_port #(logic [31:0]) instr_ap;

  function new(string name = "cpu_ref_model", uvm_component parent = null);
    super.new(name, parent);
    max_instructions = 10000;
    instr_ap = new("instr_ap", this);
  endfunction

  // Reset all state
  function void reset();
    foreach (regs[i]) regs[i] = 32'h0;
    memory.delete();
    pc           = 32'h0;
    halted       = 0;
    instr_count  = 0;
  endfunction

  // Preload instruction memory (word array starting at address 0)
  function void preload_program(logic [31:0] prog[], int num_words);
    for (int i = 0; i < num_words; i++) begin
      memory[i] = prog[i];
    end
  endfunction

  // Read a word from memory model
  function logic [31:0] mem_read_word(logic [31:0] addr);
    int idx = addr >> 2;
    if (memory.exists(idx))
      return memory[idx];
    else
      return 32'h0;
  endfunction

  // Write a word to memory model
  function void mem_write_word(logic [31:0] addr, logic [31:0] data, logic [3:0] strb);
    int idx = addr >> 2;
    logic [31:0] old_val;

    if (memory.exists(idx))
      old_val = memory[idx];
    else
      old_val = 32'h0;

    for (int i = 0; i < 4; i++) begin
      if (strb[i])
        old_val[i*8 +: 8] = data[i*8 +: 8];
    end
    memory[idx] = old_val;
  endfunction

  // Set register (x0 always 0)
  function void set_reg(int rd, logic [31:0] val);
    if (rd != 0) regs[rd] = val;
  endfunction

  // Execute the entire program until halt or max_instructions
  function void run_program();
    while (!halted && instr_count < max_instructions) begin
      step();
    end
    if (instr_count >= max_instructions)
      `uvm_warning(get_type_name(), $sformatf("Hit max instruction limit (%0d)", max_instructions))
  endfunction

  // Execute one instruction
  function void step();
    logic [31:0] instr;
    logic [6:0]  opcode;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    logic [31:0] rs1_val, rs2_val;
    logic [31:0] result;
    logic [31:0] next_pc;
    logic [31:0] mem_addr;
    logic [31:0] old_pc;
    string trace;

    if (halted) return;

    // Fetch
    old_pc = pc;
    instr = mem_read_word(pc);
    instr_count++;
    
    // Broadcast instruction for coverage collection
    instr_ap.write(instr);

    // Decode fields
    opcode = instr[6:0];
    rd     = instr[11:7];
    funct3 = instr[14:12];
    rs1    = instr[19:15];
    rs2    = instr[24:20];
    funct7 = instr[31:25];

    // Immediates
    imm_i = {{20{instr[31]}}, instr[31:20]};
    imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    imm_u = {instr[31:12], 12'h0};
    imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    rs1_val = regs[rs1];
    rs2_val = regs[rs2];
    next_pc = pc + 4;
    trace = "";

    case (opcode)
      // LUI
      7'b0110111: begin
        result = imm_u;
        set_reg(rd, result);
        trace = $sformatf("LUI  x%0d <= 0x%08h", rd, result);
      end

      // AUIPC
      7'b0010111: begin
        result = pc + imm_u;
        set_reg(rd, result);
        trace = $sformatf("AUIPC x%0d <= PC(0x%08h) + 0x%08h = 0x%08h",
                          rd, pc, imm_u, result);
      end

      // JAL
      7'b1101111: begin
        set_reg(rd, pc + 4);
        next_pc = pc + imm_j;
        trace = $sformatf("JAL  x%0d <= 0x%08h, next_pc=0x%08h", rd, pc + 4, next_pc);
      end

      // JALR
      7'b1100111: begin
        set_reg(rd, pc + 4);
        next_pc = (rs1_val + imm_i) & 32'hFFFFFFFE;
        trace = $sformatf("JALR x%0d <= 0x%08h, next_pc=0x%08h", rd, pc + 4, next_pc);
      end

      // BRANCH
      7'b1100011: begin
        bit taken = 0;
        case (funct3)
          3'b000: taken = (rs1_val == rs2_val);                        // BEQ
          3'b001: taken = (rs1_val != rs2_val);                        // BNE
          3'b100: taken = ($signed(rs1_val) < $signed(rs2_val));       // BLT
          3'b101: taken = ($signed(rs1_val) >= $signed(rs2_val));      // BGE
          3'b110: taken = (rs1_val < rs2_val);                         // BLTU
          3'b111: taken = (rs1_val >= rs2_val);                        // BGEU
          default: begin
            halted = 1;
            `uvm_info(get_type_name(), $sformatf("REF STEP %03d PC=0x%08h INSTR=0x%08h  HALT: illegal branch funct3=%0b", instr_count - 1, old_pc, instr, funct3), UVM_LOW)
            return;
          end
        endcase
        if (taken) next_pc = pc + imm_b;
        trace = $sformatf("BRANCH funct3=%0b x%0d=0x%08h x%0d=0x%08h taken=%0d next_pc=0x%08h",
                          funct3, rs1, rs1_val, rs2, rs2_val, taken, next_pc);
      end

      // LOAD
      7'b0000011: begin
        logic [31:0] word_data;
        mem_addr  = rs1_val + imm_i;
        word_data = mem_read_word({mem_addr[31:2], 2'b00});

        case (funct3)
          3'b010: begin // LW
            set_reg(rd, word_data);
          end
          3'b001: begin // LH
            logic [15:0] hw;
            hw = mem_addr[1] ? word_data[31:16] : word_data[15:0];
            set_reg(rd, {{16{hw[15]}}, hw});
          end
          3'b000: begin // LB
            logic [7:0] bv;
            case (mem_addr[1:0])
              2'd0: bv = word_data[7:0];
              2'd1: bv = word_data[15:8];
              2'd2: bv = word_data[23:16];
              2'd3: bv = word_data[31:24];
            endcase
            set_reg(rd, {{24{bv[7]}}, bv});
          end
          3'b101: begin // LHU
            logic [15:0] hw;
            hw = mem_addr[1] ? word_data[31:16] : word_data[15:0];
            set_reg(rd, {16'h0, hw});
          end
          3'b100: begin // LBU
            logic [7:0] bv;
            case (mem_addr[1:0])
              2'd0: bv = word_data[7:0];
              2'd1: bv = word_data[15:8];
              2'd2: bv = word_data[23:16];
              2'd3: bv = word_data[31:24];
            endcase
            set_reg(rd, {24'h0, bv});
          end
          default: begin
            halted = 1;
            `uvm_info(get_type_name(), $sformatf("REF STEP %03d PC=0x%08h INSTR=0x%08h  HALT: illegal load funct3=%0b", instr_count - 1, old_pc, instr, funct3), UVM_LOW)
            return;
          end
        endcase
        trace = $sformatf("LOAD funct3=%0b x%0d <= MEM[0x%08h] -> 0x%08h",
                          funct3, rd, mem_addr, regs[rd]);
      end

      // STORE
      7'b0100011: begin
        logic [3:0]  wstrb;
        logic [31:0] wdata;
        mem_addr = rs1_val + imm_s;

        case (funct3)
          3'b010: begin // SW
            wstrb = 4'b1111;
            wdata = rs2_val;
          end
          3'b001: begin // SH
            if (mem_addr[1]) begin
              wstrb = 4'b1100;
              wdata = {rs2_val[15:0], 16'h0};
            end else begin
              wstrb = 4'b0011;
              wdata = {16'h0, rs2_val[15:0]};
            end
          end
          3'b000: begin // SB
            case (mem_addr[1:0])
              2'd0: begin wstrb = 4'b0001; wdata = {24'h0, rs2_val[7:0]}; end
              2'd1: begin wstrb = 4'b0010; wdata = {16'h0, rs2_val[7:0], 8'h0}; end
              2'd2: begin wstrb = 4'b0100; wdata = {8'h0,  rs2_val[7:0], 16'h0}; end
              2'd3: begin wstrb = 4'b1000; wdata = {rs2_val[7:0], 24'h0}; end
            endcase
          end
          default: begin
            halted = 1;
            `uvm_info(get_type_name(), $sformatf("REF STEP %03d PC=0x%08h INSTR=0x%08h  HALT: illegal store funct3=%0b", instr_count - 1, old_pc, instr, funct3), UVM_LOW)
            return;
          end
        endcase
        mem_write_word({mem_addr[31:2], 2'b00}, wdata, wstrb);
        trace = $sformatf("STORE funct3=%0b MEM[0x%08h] <= x%0d(0x%08h) strb=0x%0h word=0x%08h",
                          funct3, mem_addr, rs2, rs2_val, wstrb, mem_read_word({mem_addr[31:2], 2'b00}));
      end

      // OP-IMM (I-type ALU)
      7'b0010011: begin
        case (funct3)
          3'b000: begin result = rs1_val + imm_i; set_reg(rd, result); trace = $sformatf("ADDI x%0d <= x%0d(0x%08h) + %0d = 0x%08h", rd, rs1, rs1_val, $signed(imm_i), result); end
          3'b010: begin result = {31'h0, ($signed(rs1_val) < $signed(imm_i))}; set_reg(rd, result); trace = $sformatf("SLTI x%0d <= signed(x%0d) < %0d -> 0x%08h", rd, rs1, $signed(imm_i), result); end
          3'b011: begin result = {31'h0, (rs1_val < imm_i)}; set_reg(rd, result); trace = $sformatf("SLTIU x%0d <= x%0d < 0x%08h -> 0x%08h", rd, rs1, imm_i, result); end
          3'b100: begin result = rs1_val ^ imm_i; set_reg(rd, result); trace = $sformatf("XORI x%0d <= x%0d(0x%08h) ^ 0x%08h = 0x%08h", rd, rs1, rs1_val, imm_i, result); end
          3'b110: begin result = rs1_val | imm_i; set_reg(rd, result); trace = $sformatf("ORI  x%0d <= x%0d(0x%08h) | 0x%08h = 0x%08h", rd, rs1, rs1_val, imm_i, result); end
          3'b111: begin result = rs1_val & imm_i; set_reg(rd, result); trace = $sformatf("ANDI x%0d <= x%0d(0x%08h) & 0x%08h = 0x%08h", rd, rs1, rs1_val, imm_i, result); end
          3'b001: begin result = rs1_val << imm_i[4:0]; set_reg(rd, result); trace = $sformatf("SLLI x%0d <= x%0d(0x%08h) << %0d = 0x%08h", rd, rs1, rs1_val, imm_i[4:0], result); end
          3'b101: begin
            if (funct7[5]) begin
              result = $signed(rs1_val) >>> imm_i[4:0];                    // SRAI
              trace = $sformatf("SRAI x%0d <= signed(x%0d=0x%08h) >>> %0d = 0x%08h", rd, rs1, rs1_val, imm_i[4:0], result);
            end else begin
              result = rs1_val >> imm_i[4:0];                              // SRLI
              trace = $sformatf("SRLI x%0d <= x%0d(0x%08h) >> %0d = 0x%08h", rd, rs1, rs1_val, imm_i[4:0], result);
            end
            set_reg(rd, result);
          end
          default: begin
            halted = 1;
            `uvm_info(get_type_name(), $sformatf("REF STEP %03d PC=0x%08h INSTR=0x%08h  HALT: illegal OP-IMM funct3=%0b", instr_count - 1, old_pc, instr, funct3), UVM_LOW)
            return;
          end
        endcase
      end

      // OP (R-type ALU)
      7'b0110011: begin
        case ({funct7, funct3})
          {7'b0000000, 3'b000}: begin result = rs1_val + rs2_val; set_reg(rd, result); trace = $sformatf("ADD  x%0d <= x%0d(0x%08h) + x%0d(0x%08h) = 0x%08h", rd, rs1, rs1_val, rs2, rs2_val, result); end
          {7'b0100000, 3'b000}: begin result = rs1_val - rs2_val; set_reg(rd, result); trace = $sformatf("SUB  x%0d <= x%0d(0x%08h) - x%0d(0x%08h) = 0x%08h", rd, rs1, rs1_val, rs2, rs2_val, result); end
          {7'b0000000, 3'b001}: begin result = rs1_val << rs2_val[4:0]; set_reg(rd, result); trace = $sformatf("SLL  x%0d <= x%0d(0x%08h) << x%0d[4:0](%0d) = 0x%08h", rd, rs1, rs1_val, rs2, rs2_val[4:0], result); end
          {7'b0000000, 3'b010}: begin result = {31'h0, ($signed(rs1_val) < $signed(rs2_val))}; set_reg(rd, result); trace = $sformatf("SLT  x%0d <= signed(x%0d) < signed(x%0d) -> 0x%08h", rd, rs1, rs2, result); end
          {7'b0000000, 3'b011}: begin result = {31'h0, (rs1_val < rs2_val)}; set_reg(rd, result); trace = $sformatf("SLTU x%0d <= x%0d < x%0d -> 0x%08h", rd, rs1, rs2, result); end
          {7'b0000000, 3'b100}: begin result = rs1_val ^ rs2_val; set_reg(rd, result); trace = $sformatf("XOR  x%0d <= x%0d(0x%08h) ^ x%0d(0x%08h) = 0x%08h", rd, rs1, rs1_val, rs2, rs2_val, result); end
          {7'b0000000, 3'b101}: begin result = rs1_val >> rs2_val[4:0]; set_reg(rd, result); trace = $sformatf("SRL  x%0d <= x%0d(0x%08h) >> x%0d[4:0](%0d) = 0x%08h", rd, rs1, rs1_val, rs2, rs2_val[4:0], result); end
          {7'b0100000, 3'b101}: begin result = $signed(rs1_val) >>> rs2_val[4:0]; set_reg(rd, result); trace = $sformatf("SRA  x%0d <= signed(x%0d=0x%08h) >>> x%0d[4:0](%0d) = 0x%08h", rd, rs1, rs1_val, rs2, rs2_val[4:0], result); end
          {7'b0000000, 3'b110}: begin result = rs1_val | rs2_val; set_reg(rd, result); trace = $sformatf("OR   x%0d <= x%0d(0x%08h) | x%0d(0x%08h) = 0x%08h", rd, rs1, rs1_val, rs2, rs2_val, result); end
          {7'b0000000, 3'b111}: begin result = rs1_val & rs2_val; set_reg(rd, result); trace = $sformatf("AND  x%0d <= x%0d(0x%08h) & x%0d(0x%08h) = 0x%08h", rd, rs1, rs1_val, rs2, rs2_val, result); end
          default: begin
            halted = 1;
            `uvm_info(get_type_name(), $sformatf("REF STEP %03d PC=0x%08h INSTR=0x%08h  HALT: illegal OP funct7=0x%02h funct3=%0b", instr_count - 1, old_pc, instr, funct7, funct3), UVM_LOW)
            return;
          end
        endcase
      end

      // MISC-MEM (FENCE) - treated as illegal (CPU halts)
      7'b0001111: begin
        halted = 1;
        `uvm_info(get_type_name(), $sformatf("REF STEP %03d PC=0x%08h INSTR=0x%08h  HALT: FENCE treated as illegal", instr_count - 1, old_pc, instr), UVM_LOW)
        return;
      end

      // SYSTEM (ECALL/EBREAK) - treated as illegal (CPU halts)
      7'b1110011: begin
        halted = 1;
        `uvm_info(get_type_name(), $sformatf("REF STEP %03d PC=0x%08h INSTR=0x%08h  HALT: SYSTEM treated as illegal", instr_count - 1, old_pc, instr), UVM_LOW)
        return;
      end

      default: begin
        halted = 1;
        `uvm_info(get_type_name(), $sformatf("REF STEP %03d PC=0x%08h INSTR=0x%08h  HALT: illegal/unknown opcode=0x%02h", instr_count - 1, old_pc, instr, opcode), UVM_LOW)
        return;
      end
    endcase

    `uvm_info(get_type_name(), $sformatf("REF STEP %03d PC=0x%08h INSTR=0x%08h  %s", instr_count - 1, old_pc, instr, trace), UVM_LOW)

    pc = next_pc;
  endfunction

  // Print architectural state summary
  function void print_state();
    string s;
    s = $sformatf("\n=== Reference Model State (PC=0x%08h, %0d instrs) ===\n", pc, instr_count);
    for (int i = 0; i < 32; i++) begin
      s = {s, $sformatf("  x%02d = 0x%08h", i, regs[i])};
      if ((i % 4) == 3) s = {s, "\n"};
    end
    `uvm_info(get_type_name(), s, UVM_LOW)
  endfunction

endclass : cpu_ref_model
