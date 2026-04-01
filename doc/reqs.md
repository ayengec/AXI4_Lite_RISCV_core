# RV32I CPU — Hardware Requirements Document

**Version:** 0.2  
**Date:** 2026-04-01  

---

## Table of Contents

1. [System Level Requirements](#1-system-level-requirements)
2. [Port Definition](#2-port-definition)
3. [Register File Requirements](#3-register-file-requirements)
4. [Instruction Fetch Requirements](#4-instruction-fetch-requirements)
5. [Instruction Decode Requirements](#5-instruction-decode-requirements)
6. [ALU Requirements](#6-alu-requirements)
7. [Branch and Jump Requirements](#7-branch-and-jump-requirements)
8. [Memory Access Requirements](#8-memory-access-requirements)
9. [Exception and Illegal Instruction Requirements](#9-exception-and-illegal-instruction-requirements)

---

## 1. System Level Requirements

| UID | Title | Statement |
|-----|-------|-----------|
| SYS-001 | RISC-V ISA Compliance | The CPU shall implement the RISC-V RV32I base integer instruction set as defined in the RISC-V Unprivileged ISA Specification. |
| SYS-002 | Harvard Architecture | The CPU shall use a Harvard memory architecture with separate instruction memory (IMEM) and data memory (DMEM) interfaces. |
| SYS-003 | Single-Cycle Execution | The CPU shall complete the execution of each instruction within a single clock cycle, excluding memory stall cycles. |
| SYS-004 | Clock Interface | The CPU shall operate on a single synchronous clock domain driven by the `clk` input. |
| SYS-005 | Reset Interface | The CPU shall support an active-low asynchronous reset signal (`rst_n`). Upon deassertion of reset, the CPU shall begin execution from the reset vector address. |
| SYS-006 | Reset Vector | Upon reset deassertion, the Program Counter (PC) shall be initialized to the reset vector address `0x00000000`. |
| SYS-007 | Data Width | The CPU shall operate on 32-bit data words throughout all internal datapaths. |
| SYS-008 | Address Space | The CPU shall support a 32-bit physical address space for both instruction and data memory. |
| SYS-009 | Dual AXI4-Lite Master Interfaces | The CPU shall expose two independent AXI4-Lite master interfaces: one for instruction fetch (IMEM) and one for data memory access (DMEM). |

---

## 2. Port Definition

### 2.1 Global Signals

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock, rising-edge triggered |
| `rst_n` | input | 1 | Asynchronous active-low reset |
| `illegal_instr` | output | 1 | Asserted when an illegal instruction or misaligned access is detected |

### 2.2 IMEM AXI4-Lite Master Interface (Read Only)

> Instruction memory is read-only. Only the AR and R channels are implemented.

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `imem_axi_arvalid` | output | 1 | Read address valid |
| `imem_axi_arready` | input | 1 | Read address ready (slave) |
| `imem_axi_araddr` | output | 32 | Read address (current PC value) |
| `imem_axi_arprot` | output | 3 | Protection type, driven to `3'b100` (instruction, non-secure, unprivileged) |
| `imem_axi_rvalid` | input | 1 | Read data valid (slave) |
| `imem_axi_rready` | output | 1 | Read data ready |
| `imem_axi_rdata` | input | 32 | Read data (fetched instruction) |
| `imem_axi_rresp` | input | 2 | Read response (`2'b00` = OKAY expected) |

### 2.3 DMEM AXI4-Lite Master Interface (Read / Write)

> Data memory supports both read (load) and write (store) transactions.

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `dmem_axi_awvalid` | output | 1 | Write address valid |
| `dmem_axi_awready` | input | 1 | Write address ready (slave) |
| `dmem_axi_awaddr` | output | 32 | Write address |
| `dmem_axi_awprot` | output | 3 | Protection type, driven to `3'b000` (data, non-secure, unprivileged) |
| `dmem_axi_wvalid` | output | 1 | Write data valid |
| `dmem_axi_wready` | input | 1 | Write data ready (slave) |
| `dmem_axi_wdata` | output | 32 | Write data |
| `dmem_axi_wstrb` | output | 4 | Write strobe (byte enables) |
| `dmem_axi_bvalid` | input | 1 | Write response valid (slave) |
| `dmem_axi_bready` | output | 1 | Write response ready |
| `dmem_axi_bresp` | input | 2 | Write response (`2'b00` = OKAY expected) |
| `dmem_axi_arvalid` | output | 1 | Read address valid |
| `dmem_axi_arready` | input | 1 | Read address ready (slave) |
| `dmem_axi_araddr` | output | 32 | Read address |
| `dmem_axi_arprot` | output | 3 | Protection type, driven to `3'b000` (data, non-secure, unprivileged) |
| `dmem_axi_rvalid` | input | 1 | Read data valid (slave) |
| `dmem_axi_rready` | output | 1 | Read data ready |
| `dmem_axi_rdata` | input | 32 | Read data |
| `dmem_axi_rresp` | input | 2 | Read response (`2'b00` = OKAY expected) |

---

## 3. Register File Requirements

| UID | Title | Statement |
|-----|-------|-----------|
| RF-001 | General Purpose Registers | The CPU shall implement 32 general-purpose integer registers, x0 through x31, each 32 bits wide. |
| RF-002 | Zero Register | Register x0 shall be hardwired to the value `0x00000000`. Any write operation to x0 shall be silently discarded. |
| RF-003 | Register Reset Value | Registers x1 through x31 shall be initialized to `0x00000000` upon reset deassertion. |
| RF-004 | Synchronous Write | Register write operations shall be synchronous, occurring on the rising edge of `clk`. |
| RF-005 | Asynchronous Read | Register read operations shall be asynchronous (combinational), providing the register value in the same clock cycle as the read request. |
| RF-006 | Dual Read Ports | The register file shall support simultaneous read of two source registers (rs1 and rs2) in a single clock cycle. |
| RF-007 | Single Write Port | The register file shall support one write port for the destination register (rd). |
| RF-008 | Read-During-Write | If a read and write to the same register occur simultaneously, the read shall return the new (written) value (forward path). |

---

## 4. Instruction Fetch Requirements

| UID | Title | Statement |
|-----|-------|-----------|
| IF-001 | Instruction Width | The CPU shall fetch 32-bit wide instructions from the IMEM AXI4-Lite interface on every clock cycle unless stalled. |
| IF-002 | PC Increment | The Program Counter shall increment by 4 (bytes) after each successfully fetched instruction that is not a branch or jump. |
| IF-003 | PC Update on Branch Taken | When a branch instruction is taken, the PC shall be updated to the branch target address in the same clock cycle as the branch decision. |
| IF-004 | PC Update on Jump | When a JAL or JALR instruction is executed, the PC shall be updated to the computed jump target address. |
| IF-005 | Instruction Alignment | All instruction fetches shall be 32-bit aligned. A fetch from a non-word-aligned address shall be treated as an illegal operation. |
| IF-006 | IMEM Read-Only | The CPU shall not initiate AXI4-Lite write transactions on the IMEM interface. Only AR and R channels shall be driven. |
| IF-007 | IMEM ARADDR | The CPU shall drive the current PC value onto `imem_axi_araddr` each cycle a fetch is initiated. |
| IF-008 | IMEM ARPROT | The CPU shall drive `imem_axi_arprot` to `3'b100` (instruction access) on all IMEM transactions. |
| IF-009 | Stall on IMEM Not Ready | If `imem_axi_rvalid` is not asserted, the CPU shall stall the fetch stage and hold the current PC value until the instruction data is available. |

---

## 5. Instruction Decode Requirements

| UID | Title | Statement |
|-----|-------|-----------|
| ID-001 | Instruction Format Support | The decode stage shall correctly identify and parse all six RV32I instruction formats: R-type, I-type, S-type, B-type, U-type, and J-type. |
| ID-002 | Opcode Decode | The decode stage shall extract bits [6:0] as the opcode field and use it to determine the instruction type and required execution unit. |
| ID-003 | Source Register Decode | The decode stage shall extract rs1 from bits [19:15] and rs2 from bits [24:20] and use these to address the register file read ports. |
| ID-004 | Destination Register Decode | The decode stage shall extract rd from bits [11:7] and use it to address the register file write port. |
| ID-005 | Funct3 Decode | The decode stage shall extract funct3 from bits [14:12] and use it together with the opcode to uniquely identify the instruction operation. |
| ID-006 | Funct7 Decode | The decode stage shall extract funct7 from bits [31:25] and use it to differentiate between instructions sharing the same opcode and funct3 (e.g. ADD vs SUB, SRL vs SRA). |
| ID-007 | I-type Immediate | The decode stage shall sign-extend the I-type immediate from bits [31:20] to 32 bits. |
| ID-008 | S-type Immediate | The decode stage shall reconstruct and sign-extend the S-type immediate from bits [31:25] and bits [11:7] to 32 bits. |
| ID-009 | B-type Immediate | The decode stage shall reconstruct and sign-extend the B-type immediate from bits [31], [7], [30:25], and [11:8], with bit 0 implicitly zero, to 32 bits. |
| ID-010 | U-type Immediate | The decode stage shall reconstruct the U-type immediate by placing bits [31:12] in the upper 20 bits of the 32-bit result and zero-filling the lower 12 bits. |
| ID-011 | J-type Immediate | The decode stage shall reconstruct and sign-extend the J-type immediate from bits [31], [19:12], [20], and [30:21], with bit 0 implicitly zero, to 32 bits. |
| ID-012 | Illegal Instruction Detection | The decode stage shall assert an illegal instruction flag when an unrecognized opcode or unsupported funct3/funct7 combination is encountered. |

---

## 6. ALU Requirements

### 6.1 Arithmetic Operations

| UID | Title | Statement |
|-----|-------|-----------|
| ALU-001 | ADD | The ALU shall compute the 32-bit sum of two operands (rs1 + rs2 or rs1 + imm). Overflow shall be ignored and the result shall wrap around. |
| ALU-002 | SUB | The ALU shall compute the 32-bit difference of two register operands (rs1 - rs2). Overflow shall be ignored and the result shall wrap around. |
| ALU-003 | ADDI | The ALU shall compute rs1 + sign_extended(imm[11:0]) and write the result to rd. |

### 6.2 Logical Operations

| UID | Title | Statement |
|-----|-------|-----------|
| ALU-004 | AND / ANDI | The ALU shall compute the bitwise AND of rs1 and rs2 (or sign-extended immediate for ANDI). |
| ALU-005 | OR / ORI | The ALU shall compute the bitwise OR of rs1 and rs2 (or sign-extended immediate for ORI). |
| ALU-006 | XOR / XORI | The ALU shall compute the bitwise XOR of rs1 and rs2 (or sign-extended immediate for XORI). |

### 6.3 Shift Operations

| UID | Title | Statement |
|-----|-------|-----------|
| ALU-007 | SLL / SLLI | The ALU shall shift rs1 left by the shift amount (lower 5 bits of rs2 or shamt field), filling vacated bits with zeros. |
| ALU-008 | SRL / SRLI | The ALU shall shift rs1 right by the shift amount (lower 5 bits of rs2 or shamt field), filling vacated bits with zeros. |
| ALU-009 | SRA / SRAI | The ALU shall shift rs1 right by the shift amount (lower 5 bits of rs2 or shamt field), filling vacated bits with the sign bit of rs1. |

### 6.4 Comparison Operations

| UID | Title | Statement |
|-----|-------|-----------|
| ALU-010 | SLT | The ALU shall write 1 to rd if rs1 is less than rs2 (signed comparison), otherwise write 0. |
| ALU-011 | SLTU | The ALU shall write 1 to rd if rs1 is less than rs2 (unsigned comparison), otherwise write 0. |
| ALU-012 | SLTI | The ALU shall write 1 to rd if rs1 is less than the sign-extended immediate (signed comparison), otherwise write 0. |
| ALU-013 | SLTIU | The ALU shall write 1 to rd if rs1 is less than the sign-extended immediate (unsigned comparison), otherwise write 0. |

### 6.5 Upper Immediate Operations

| UID | Title | Statement |
|-----|-------|-----------|
| ALU-014 | LUI | The ALU shall place the U-type immediate into the upper 20 bits of rd, zeroing the lower 12 bits. rs1 shall not be used. |
| ALU-015 | AUIPC | The ALU shall add the U-type immediate (upper 20 bits) to the current PC value and write the result to rd. |

---

## 7. Branch and Jump Requirements

### 7.1 Conditional Branches

| UID | Title | Statement |
|-----|-------|-----------|
| BRN-001 | BEQ | The CPU shall branch to PC + B-type immediate if rs1 equals rs2. Otherwise the PC shall increment to PC+4. |
| BRN-002 | BNE | The CPU shall branch to PC + B-type immediate if rs1 does not equal rs2. Otherwise the PC shall increment to PC+4. |
| BRN-003 | BLT | The CPU shall branch to PC + B-type immediate if rs1 is less than rs2 (signed). Otherwise the PC shall increment to PC+4. |
| BRN-004 | BLTU | The CPU shall branch to PC + B-type immediate if rs1 is less than rs2 (unsigned). Otherwise the PC shall increment to PC+4. |
| BRN-005 | BGE | The CPU shall branch to PC + B-type immediate if rs1 is greater than or equal to rs2 (signed). Otherwise the PC shall increment to PC+4. |
| BRN-006 | BGEU | The CPU shall branch to PC + B-type immediate if rs1 is greater than or equal to rs2 (unsigned). Otherwise the PC shall increment to PC+4. |
| BRN-007 | Branch Target Alignment | The branch target address shall be 4-byte aligned. A branch to a non-aligned address shall be treated as an illegal operation. |

### 7.2 Jump Instructions

| UID | Title | Statement |
|-----|-------|-----------|
| JMP-001 | JAL | The CPU shall unconditionally set PC to PC + J-type immediate and write PC+4 to rd. |
| JMP-002 | JALR | The CPU shall set PC to (rs1 + sign_extended(imm[11:0])) with bit 0 cleared, and write PC+4 to rd. |
| JMP-003 | JAL/JALR with rd=x0 | When rd is x0, the return address shall be discarded (no write to register file). |

---

## 8. Memory Access Requirements

### 8.1 Load Instructions

| UID | Title | Statement |
|-----|-------|-----------|
| MEM-001 | LW | The CPU shall read a 32-bit word from address (rs1 + sign_extended(imm)) and write the value to rd. |
| MEM-002 | LH | The CPU shall read a 16-bit halfword from address (rs1 + sign_extended(imm)), sign-extend to 32 bits, and write to rd. |
| MEM-003 | LHU | The CPU shall read a 16-bit halfword from address (rs1 + sign_extended(imm)), zero-extend to 32 bits, and write to rd. |
| MEM-004 | LB | The CPU shall read an 8-bit byte from address (rs1 + sign_extended(imm)), sign-extend to 32 bits, and write to rd. |
| MEM-005 | LBU | The CPU shall read an 8-bit byte from address (rs1 + sign_extended(imm)), zero-extend to 32 bits, and write to rd. |

### 8.2 Store Instructions

| UID | Title | Statement |
|-----|-------|-----------|
| MEM-006 | SW | The CPU shall write the 32-bit value of rs2 to address (rs1 + sign_extended(S-imm)). |
| MEM-007 | SH | The CPU shall write the lower 16 bits of rs2 to address (rs1 + sign_extended(S-imm)). |
| MEM-008 | SB | The CPU shall write the lower 8 bits of rs2 to address (rs1 + sign_extended(S-imm)). |

### 8.3 DMEM AXI4-Lite Interface Requirements

| UID | Title | Statement |
|-----|-------|-----------|
| MEM-009 | AXI4-Lite Protocol Compliance | The DMEM interface shall comply with the AXI4-Lite protocol specification. All handshake signals (VALID/READY) shall be correctly driven and observed. |
| MEM-010 | AXI Write Channel | Store instructions shall initiate an AXI4-Lite write transaction driving AW and W channels simultaneously, completing on receipt of BVALID. |
| MEM-011 | AXI Read Channel | Load instructions shall initiate an AXI4-Lite read transaction on the AR channel and shall capture data from the R channel when RVALID is asserted. |
| MEM-012 | AXI Write Strobe | `dmem_axi_wstrb` shall be driven correctly per store size: `4'b1111` for SW, 2-bit aligned mask for SH, 1-bit aligned mask for SB. |
| MEM-013 | CPU Stall on AXI Not Ready | The CPU shall stall while waiting for the DMEM AXI4-Lite transaction to complete (RVALID or BVALID not yet asserted). |
| MEM-014 | DMEM AWPROT / ARPROT | The CPU shall drive `dmem_axi_awprot` and `dmem_axi_arprot` to `3'b000` (data, non-secure, unprivileged) on all DMEM transactions. |
| MEM-015 | AXI Address Alignment — Word | LW and SW transactions shall use 4-byte aligned addresses. An unaligned word access shall be treated as an illegal operation. |
| MEM-016 | AXI Address Alignment — Halfword | LH, LHU, and SH transactions shall use 2-byte aligned addresses. An unaligned halfword access shall be treated as an illegal operation. |

---

## 9. Exception and Illegal Instruction Requirements

| UID | Title | Statement |
|-----|-------|-----------|
| EXC-001 | Illegal Instruction Trap | The CPU shall assert `illegal_instr` output when an instruction with an unrecognized opcode or unsupported funct3/funct7 combination is decoded. |
| EXC-002 | Illegal Instruction Halt | Upon detection of an illegal instruction, the CPU shall halt execution and hold `illegal_instr` asserted until reset. |
| EXC-003 | Misaligned Instruction Fetch | The CPU shall assert `illegal_instr` if the PC is not 4-byte aligned at the time of instruction fetch. |
| EXC-004 | Misaligned Memory Access | The CPU shall assert `illegal_instr` if a load or store instruction computes a memory address that violates the alignment requirements defined in MEM-015 and MEM-016. |

---

*Total: 78 requirements — SYS(9) · RF(8) · IF(9) · ID(12) · ALU(15) · BRN/JMP(10) · MEM(16) · EXC(4)*
