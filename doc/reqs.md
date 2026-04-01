# RV32I CPU — Hardware Requirements Document

**Version:** 1.0  
**Date:** ---

---

## Scope

This document defines the hardware requirements for a simple RV32I CPU implemented as a **single-issue, non-pipelined, stallable core** with a **single AXI4-Lite master interface** shared between instruction fetch and data memory access. Pipelining, caching, branch prediction, and support for multiple outstanding bus transactions are **out of scope** for this revision.

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
| SYS-002 | Execution Model | The CPU shall operate as a single-issue, non-pipelined execution engine. |
| SYS-003 | Stallable Operation | The CPU shall stall execution when waiting for instruction or data transfers on the AXI4-Lite interface to complete. |
| SYS-004 | Clock Interface | The CPU shall operate on a single synchronous clock domain driven by the `clk` input. |
| SYS-005 | Reset Interface | The CPU shall support an active-low asynchronous reset signal (`rst_n`). Upon deassertion of reset, the CPU shall begin execution from the reset vector address. |
| SYS-006 | Reset Vector | Upon reset deassertion, the Program Counter (PC) shall be initialized to the reset vector address `0x00000000`. |
| SYS-007 | Data Width | The CPU shall operate on 32-bit data words throughout all internal datapaths. |
| SYS-008 | Address Space | The CPU shall support a 32-bit physical address space for instruction and data accesses. |
| SYS-009 | Single AXI4-Lite Master Interface | The CPU shall expose one AXI4-Lite master interface used for both instruction fetch and data memory access. |
| SYS-010 | Single Outstanding Transaction | The CPU shall support at most one outstanding AXI4-Lite transaction at any time. |
| SYS-011 | Serialized Memory Access | Instruction fetch and data memory access shall not be issued concurrently on the AXI4-Lite interface. |

---

## 2. Port Definition

### 2.1 Global Signals

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock, rising-edge triggered |
| `rst_n` | input | 1 | Asynchronous active-low reset |
| `illegal_instr` | output | 1 | Asserted when an illegal instruction, bus error, or misaligned access is detected |

### 2.2 AXI4-Lite Master Interface

> A single AXI4-Lite master interface is shared between instruction fetch and data memory access.

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `axi_awvalid` | output | 1 | Write address valid |
| `axi_awready` | input | 1 | Write address ready |
| `axi_awaddr` | output | 32 | Write address |
| `axi_awprot` | output | 3 | Protection type for write transactions |
| `axi_wvalid` | output | 1 | Write data valid |
| `axi_wready` | input | 1 | Write data ready |
| `axi_wdata` | output | 32 | Write data |
| `axi_wstrb` | output | 4 | Write strobe (byte enables) |
| `axi_bvalid` | input | 1 | Write response valid |
| `axi_bready` | output | 1 | Write response ready |
| `axi_bresp` | input | 2 | Write response |
| `axi_arvalid` | output | 1 | Read address valid |
| `axi_arready` | input | 1 | Read address ready |
| `axi_araddr` | output | 32 | Read address |
| `axi_arprot` | output | 3 | Protection type for read transactions |
| `axi_rvalid` | input | 1 | Read data valid |
| `axi_rready` | output | 1 | Read data ready |
| `axi_rdata` | input | 32 | Read data |
| `axi_rresp` | input | 2 | Read response |

---

## 3. Register File Requirements

| UID | Title | Statement |
|-----|-------|-----------|
| RF-001 | General Purpose Registers | The CPU shall implement 32 general-purpose integer registers, x0 through x31, each 32 bits wide. |
| RF-002 | Zero Register | Register x0 shall be hardwired to the value `0x00000000`. Any write operation to x0 shall be silently discarded. |
| RF-003 | Register Reset Value | Registers x1 through x31 shall be initialized to `0x00000000` upon reset deassertion. |
| RF-004 | Synchronous Write | Register write operations shall be synchronous, occurring on the rising edge of `clk`. |
| RF-005 | Asynchronous Read | Register read operations shall be asynchronous (combinational), providing the register value in the same clock cycle as the read request. |
| RF-006 | Dual Read Ports | The register file shall support simultaneous read of two source registers (rs1 and rs2) in a single cycle. |
| RF-007 | Single Write Port | The register file shall support one write port for the destination register (rd). |
| RF-008 | Read-During-Write | If a read and write to the same register occur simultaneously, the read shall return the newly written value. |

---

## 4. Instruction Fetch Requirements

| UID | Title | Statement |
|-----|-------|-----------|
| IF-001 | Instruction Width | The CPU shall fetch 32-bit instructions. |
| IF-002 | Fetch Source | Instruction fetches shall be performed through the shared AXI4-Lite master interface. |
| IF-003 | PC Increment | The Program Counter shall increment by 4 bytes after each successfully executed non-control-flow instruction. |
| IF-004 | PC Update on Branch Taken | When a branch instruction is taken, the PC shall be updated to the branch target address. |
| IF-005 | PC Update on Jump | When a JAL or JALR instruction is executed, the PC shall be updated to the computed jump target address. |
| IF-006 | Instruction Alignment | All instruction fetches shall use 32-bit aligned addresses. A fetch from a non-word-aligned address shall be treated as an illegal operation. |
| IF-007 | ARADDR for Fetch | When initiating an instruction fetch, the CPU shall drive the current PC value onto `axi_araddr`. |
| IF-008 | ARPROT for Fetch | For instruction fetch transactions, the CPU shall drive `axi_arprot` to `3'b100` (instruction, non-secure, unprivileged). |
| IF-009 | Stall on Fetch Wait | If instruction data is not yet available, the CPU shall stall and hold the current PC until the fetch transaction completes. |
| IF-010 | No Concurrent Data Access During Fetch | The CPU shall not initiate a data memory access while an instruction fetch transaction is outstanding. |

---

## 5. Instruction Decode Requirements

| UID | Title | Statement |
|-----|-------|-----------|
| ID-001 | Instruction Format Support | The decode stage shall correctly identify and parse all six RV32I instruction formats: R-type, I-type, S-type, B-type, U-type, and J-type. |
| ID-002 | Opcode Decode | The decode stage shall extract bits `[6:0]` as the opcode field and use it to determine the instruction type and required execution unit. |
| ID-003 | Source Register Decode | The decode stage shall extract `rs1` from bits `[19:15]` and `rs2` from bits `[24:20]` and use these to address the register file read ports. |
| ID-004 | Destination Register Decode | The decode stage shall extract `rd` from bits `[11:7]` and use it to address the register file write port. |
| ID-005 | Funct3 Decode | The decode stage shall extract `funct3` from bits `[14:12]` and use it together with the opcode to identify the instruction operation. |
| ID-006 | Funct7 Decode | The decode stage shall extract `funct7` from bits `[31:25]` and use it to differentiate instructions sharing the same opcode and `funct3`. |
| ID-007 | I-type Immediate | The decode stage shall sign-extend the I-type immediate from bits `[31:20]` to 32 bits. |
| ID-008 | S-type Immediate | The decode stage shall reconstruct and sign-extend the S-type immediate from bits `[31:25]` and `[11:7]` to 32 bits. |
| ID-009 | B-type Immediate | The decode stage shall reconstruct and sign-extend the B-type immediate from bits `[31]`, `[7]`, `[30:25]`, and `[11:8]`, with bit 0 implicitly zero, to 32 bits. |
| ID-010 | U-type Immediate | The decode stage shall reconstruct the U-type immediate by placing bits `[31:12]` in the upper 20 bits of the 32-bit result and zero-filling the lower 12 bits. |
| ID-011 | J-type Immediate | The decode stage shall reconstruct and sign-extend the J-type immediate from bits `[31]`, `[19:12]`, `[20]`, and `[30:21]`, with bit 0 implicitly zero, to 32 bits. |
| ID-012 | Illegal Instruction Detection | The decode stage shall assert an illegal instruction condition when an unrecognized opcode or unsupported `funct3`/`funct7` combination is encountered. |

---

## 6. ALU Requirements

### 6.1 Arithmetic Operations

| UID | Title | Statement |
|-----|-------|-----------|
| ALU-001 | ADD | The ALU shall compute the 32-bit sum of two operands (`rs1 + rs2` or `rs1 + imm`). Overflow shall be ignored and the result shall wrap around. |
| ALU-002 | SUB | The ALU shall compute the 32-bit difference of two register operands (`rs1 - rs2`). Overflow shall be ignored and the result shall wrap around. |
| ALU-003 | ADDI | The ALU shall compute `rs1 + sign_extended(imm[11:0])` and write the result to `rd`. |

### 6.2 Logical Operations

| UID | Title | Statement |
|-----|-------|-----------|
| ALU-004 | AND / ANDI | The ALU shall compute the bitwise AND of `rs1` and `rs2` (or sign-extended immediate for ANDI). |
| ALU-005 | OR / ORI | The ALU shall compute the bitwise OR of `rs1` and `rs2` (or sign-extended immediate for ORI). |
| ALU-006 | XOR / XORI | The ALU shall compute the bitwise XOR of `rs1` and `rs2` (or sign-extended immediate for XORI). |

### 6.3 Shift Operations

| UID | Title | Statement |
|-----|-------|-----------|
| ALU-007 | SLL / SLLI | The ALU shall shift `rs1` left by the shift amount (lower 5 bits of `rs2` or shamt field), filling vacated bits with zeros. |
| ALU-008 | SRL / SRLI | The ALU shall shift `rs1` right by the shift amount (lower 5 bits of `rs2` or shamt field), filling vacated bits with zeros. |
| ALU-009 | SRA / SRAI | The ALU shall shift `rs1` right by the shift amount (lower 5 bits of `rs2` or shamt field), filling vacated bits with the sign bit of `rs1`. |

### 6.4 Comparison Operations

| UID | Title | Statement |
|-----|-------|-----------|
| ALU-010 | SLT | The ALU shall write `1` to `rd` if `rs1` is less than `rs2` (signed comparison), otherwise write `0`. |
| ALU-011 | SLTU | The ALU shall write `1` to `rd` if `rs1` is less than `rs2` (unsigned comparison), otherwise write `0`. |
| ALU-012 | SLTI | The ALU shall write `1` to `rd` if `rs1` is less than the sign-extended immediate (signed comparison), otherwise write `0`. |
| ALU-013 | SLTIU | The ALU shall write `1` to `rd` if `rs1` is less than the sign-extended immediate (unsigned comparison), otherwise write `0`. |

### 6.5 Upper Immediate Operations

| UID | Title | Statement |
|-----|-------|-----------|
| ALU-014 | LUI | The ALU shall place the U-type immediate into the upper 20 bits of `rd`, zeroing the lower 12 bits. `rs1` shall not be used. |
| ALU-015 | AUIPC | The ALU shall add the U-type immediate to the current PC value and write the result to `rd`. |

---

## 7. Branch and Jump Requirements

### 7.1 Conditional Branches

| UID | Title | Statement |
|-----|-------|-----------|
| BRN-001 | BEQ | The CPU shall branch to `PC + B-type immediate` if `rs1 == rs2`; otherwise the PC shall advance to `PC + 4`. |
| BRN-002 | BNE | The CPU shall branch to `PC + B-type immediate` if `rs1 != rs2`; otherwise the PC shall advance to `PC + 4`. |
| BRN-003 | BLT | The CPU shall branch to `PC + B-type immediate` if `rs1 < rs2` (signed); otherwise the PC shall advance to `PC + 4`. |
| BRN-004 | BLTU | The CPU shall branch to `PC + B-type immediate` if `rs1 < rs2` (unsigned); otherwise the PC shall advance to `PC + 4`. |
| BRN-005 | BGE | The CPU shall branch to `PC + B-type immediate` if `rs1 >= rs2` (signed); otherwise the PC shall advance to `PC + 4`. |
| BRN-006 | BGEU | The CPU shall branch to `PC + B-type immediate` if `rs1 >= rs2` (unsigned); otherwise the PC shall advance to `PC + 4`. |
| BRN-007 | Branch Target Alignment | Branch target addresses shall be 4-byte aligned. A branch to a non-aligned address shall be treated as an illegal operation. |

### 7.2 Jump Instructions

| UID | Title | Statement |
|-----|-------|-----------|
| JMP-001 | JAL | The CPU shall set the PC to `PC + J-type immediate` and write `PC + 4` to `rd`. |
| JMP-002 | JALR | The CPU shall set the PC to `(rs1 + sign_extended(imm[11:0]))` with bit 0 cleared, and write `PC + 4` to `rd`. |
| JMP-003 | JAL/JALR with rd=x0 | When `rd` is `x0`, the return address shall be discarded. |

---

## 8. Memory Access Requirements

### 8.1 Load Instructions

| UID | Title | Statement |
|-----|-------|-----------|
| MEM-001 | LW | The CPU shall read a 32-bit word from address `(rs1 + sign_extended(imm))` and write the value to `rd`. |
| MEM-002 | LH | The CPU shall read a 16-bit halfword from address `(rs1 + sign_extended(imm))`, sign-extend it to 32 bits, and write it to `rd`. |
| MEM-003 | LHU | The CPU shall read a 16-bit halfword from address `(rs1 + sign_extended(imm))`, zero-extend it to 32 bits, and write it to `rd`. |
| MEM-004 | LB | The CPU shall read an 8-bit byte from address `(rs1 + sign_extended(imm))`, sign-extend it to 32 bits, and write it to `rd`. |
| MEM-005 | LBU | The CPU shall read an 8-bit byte from address `(rs1 + sign_extended(imm))`, zero-extend it to 32 bits, and write it to `rd`. |
| MEM-006 | Load Lane Selection | For LB/LBU and LH/LHU, the CPU shall select the appropriate byte or halfword from `axi_rdata` based on the low address bits of the effective address. |

### 8.2 Store Instructions

| UID | Title | Statement |
|-----|-------|-----------|
| MEM-007 | SW | The CPU shall write the 32-bit value of `rs2` to address `(rs1 + sign_extended(S-imm))`. |
| MEM-008 | SH | The CPU shall write the lower 16 bits of `rs2` to address `(rs1 + sign_extended(S-imm))`. |
| MEM-009 | SB | The CPU shall write the lower 8 bits of `rs2` to address `(rs1 + sign_extended(S-imm))`. |
| MEM-010 | Store Data Placement | For SB and SH, the CPU shall place the source byte or halfword into the correct byte lanes of `axi_wdata` according to the low address bits. |

### 8.3 AXI4-Lite Interface Requirements

| UID | Title | Statement |
|-----|-------|-----------|
| MEM-011 | AXI4-Lite Protocol Compliance | The shared memory interface shall comply with the AXI4-Lite protocol specification. All VALID/READY handshakes shall be correctly driven and observed. |
| MEM-012 | AXI Read for Fetch and Load | Instruction fetches and load instructions shall initiate AXI4-Lite read transactions on the AR channel and capture data from the R channel when `axi_rvalid` is asserted. |
| MEM-013 | AXI Write for Store | Store instructions shall initiate AXI4-Lite write transactions using the AW, W, and B channels and complete on receipt of `axi_bvalid`. |
| MEM-014 | AXI Write Strobe | `axi_wstrb` shall be driven correctly per store size: `4'b1111` for SW, a 2-bit aligned mask for SH, and a 1-bit aligned mask for SB. |
| MEM-015 | Stall on Memory Wait | The CPU shall stall while waiting for a load, store, or instruction fetch transaction to complete. |
| MEM-016 | ARPROT for Data | For load transactions, the CPU shall drive `axi_arprot` to `3'b000` (data, non-secure, unprivileged). |
| MEM-017 | AWPROT for Data | For store transactions, the CPU shall drive `axi_awprot` to `3'b000` (data, non-secure, unprivileged). |
| MEM-018 | Word Alignment | LW and SW shall use 4-byte aligned addresses. An unaligned word access shall be treated as an illegal operation. |
| MEM-019 | Halfword Alignment | LH, LHU, and SH shall use 2-byte aligned addresses. An unaligned halfword access shall be treated as an illegal operation. |
| MEM-020 | Byte Access Alignment | LB, LBU, and SB may use any byte address. |
| MEM-021 | No Concurrent Fetch and Data Access | The CPU shall not issue an instruction fetch and a data memory transaction concurrently. |
| MEM-022 | Transaction Serialization | The CPU shall complete the current AXI4-Lite transaction before issuing the next one. |
| MEM-023 | Read Response Check | If `axi_rresp` is not `2'b00`, the CPU shall treat the transaction as an illegal operation and assert `illegal_instr`. |
| MEM-024 | Write Response Check | If `axi_bresp` is not `2'b00`, the CPU shall treat the transaction as an illegal operation and assert `illegal_instr`. |

---

## 9. Exception and Illegal Instruction Requirements

| UID | Title | Statement |
|-----|-------|-----------|
| EXC-001 | Illegal Instruction Trap | The CPU shall assert `illegal_instr` when an instruction with an unrecognized opcode or unsupported `funct3`/`funct7` combination is decoded. |
| EXC-002 | Illegal Instruction Halt | Upon detection of an illegal instruction, misaligned access, or bus error, the CPU shall halt execution and hold `illegal_instr` asserted until reset. |
| EXC-003 | Misaligned Instruction Fetch | The CPU shall assert `illegal_instr` if the PC is not 4-byte aligned at the time of instruction fetch. |
| EXC-004 | Misaligned Memory Access | The CPU shall assert `illegal_instr` if a load or store computes an address that violates the alignment requirements defined in MEM-018 and MEM-019. |
| EXC-005 | Bus Error Handling | The CPU shall assert `illegal_instr` if an AXI4-Lite read or write response indicates an error. |

---

*Total: 85 requirements — SYS(11) · RF(8) · IF(10) · ID(12) · ALU(15) · BRN/JMP(10) · MEM(24) · EXC(5)*
