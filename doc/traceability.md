# RV32I AXI4-Lite Subsystem Requirement Traceability Matrix

## 1. Purpose

This document maps the hardware requirements in `doc/reqs.md` to the current UVM tests, debug evidence, and coverage plan.

Status meanings:

| Status | Meaning |
|---|---|
| Covered | Current regression has directed or scoreboard-backed evidence for this requirement. |
| TODO | Current regression gives some evidence, but the requirement needs stronger directed checking, assertions, or coverage closure. |
| Planned | Current verification plan identifies this as a gap for a future test or checker. |

Primary evidence sources:

| Evidence | Description |
|---|---|
| `cpu_basic_alu_test` | ALU, immediate, upper-immediate, register writeback, checkpoint stores |
| `cpu_alu_imm_corner_test` | directed `SLTI` and `SLTIU` signed/unsigned immediate corner cases |
| `cpu_load_store_test` | byte, halfword, word load/store behavior and write strobes |
| `cpu_branch_test` | branch, jump, JALR, PC redirection, poison-instruction skipping |
| `cpu_branch_corner_test` | directed unsigned branch taken/not-taken closure for `BLTU` and `BGEU` |
| `cpu_jump_x0_test` | directed `JAL`/`JALR` with `rd == x0` return-address discard behavior |
| `cpu_reg_coverage_sweep_test` | targeted register-field and SYSTEM opcode coverage closure |
| `cpu_mem_lane_sweep_test` | targeted byte/halfword memory lane coverage closure |
| `cpu_regfile_semantics_test` | targeted x0 discard and dependent register-read behavior |
| `cpu_misaligned_access_test` | misaligned load/store halt behavior |
| `cpu_misaligned_control_test` | misaligned branch/jump target halt behavior |
| `cpu_invalid_decode_test` | invalid decode and unsupported encoding halt behavior |
| `cpu_axi_wait_state_test` | AXI read/write wait-state behavior |
| `cpu_axi_error_test` | AXI fetch/load/store response error halt behavior |
| `cpu_branch_unit_force_test` | force-only defensive branch-unit default coverage |
| `cpu_illegal_instr_test` | unsupported instruction halt behavior |
| `cpu_random_test` | randomized valid ALU/checkpoint stress |
| `cpu_ref_model` | golden architectural state calculation |
| `cpu_scoreboard` | final register and data-memory comparison |
| `cpu_protocol_assertions` | reset sanity, AXI protection, valid-stable, no-overlap, and single-outstanding protocol checks |
| `cpu_regfile_assertions` | synchronous write, x0 stability, and read-port consistency checks |
| `DUT_TRACE` | fetch, load, store, writeback, and halt debug evidence |
| `cpu_coverage` | instruction-level functional coverage |
| `my_run_logs/regression_trace_examples.md` | sanitized example evidence from regression logs |

## 2. System Requirements

| Req ID | Title | Covered by | Evidence | Status | Notes |
|---|---|---|---|---|---|
| SYS-001 | RISC-V ISA Compliance | directed tests, `cpu_random_test`, `cpu_ref_model`, `cpu_coverage` | supported RV32I subset executes and compares against reference model | Covered | Planned functional coverage bins are closed for the current RV32I subset. |
| SYS-002 | Execution Model | all tests, `DUT_TRACE` | serialized fetch/execute/memory/halt trace | Covered | Current tests observe non-pipelined sequential execution. |
| SYS-003 | Stallable Operation | `cpu_axi_wait_state_test`, `axi4lite_ram`, `DUT_TRACE` | fetch/load/store wait behavior visible in traces | Covered | Directed read/write wait cycles are inserted by the RAM model. |
| SYS-004 | Clock Interface | `cpu_tb_top`, all tests | all tests run on one clock | Covered | Structural plus simulation evidence. |
| SYS-005 | Reset Interface | all tests, `cpu_protocol_assertions` | reset release before execution; reset vector, x0, and illegal flag sanity checked during reset | Covered | Assertion-backed reset sanity is now present. |
| SYS-006 | Reset Vector | all tests, `DUT_TRACE` | first fetch at `PC=0x00000000` | Covered | Visible in every regression trace. |
| SYS-007 | Data Width | all tests, `cpu_scoreboard` | 32-bit register and memory values compared | Covered | ALU/load/store checkpoints use 32-bit architectural state. |
| SYS-008 | Address Space | `cpu_address_boundary_test`, load/store and branch tests | 32-bit addresses in fetch/data traces, including the upper implemented RAM word address | Covered | Current project verifies the implemented RAM window; full external address-space stress is out of scope for this revision. |
| SYS-009 | Single AXI4-Lite Master Interface | all tests, `rv32i_cpu`, `DUT_TRACE` | instruction and data traffic share one interface | Covered | Structural plus trace evidence. |
| SYS-010 | Single Outstanding Transaction | all tests, `DUT_TRACE`, `cpu_protocol_assertions` | no overlapping fetch/load/store transactions observed and asserted | Covered | Assertion tracks outstanding read/write requests and responses. |
| SYS-011 | Serialized Memory Access | all tests, `DUT_TRACE` | fetch and data transactions occur in sequence | Covered | Current trace monitor makes serialized behavior visible. |

## 3. Register File Requirements

| Req ID | Title | Covered by | Evidence | Status | Notes |
|---|---|---|---|---|---|
| RF-001 | General Purpose Registers | `cpu_scoreboard`, all tests | all 32 registers compared | Covered | Scoreboard reads and compares x0-x31. |
| RF-002 | Zero Register | `cpu_basic_alu_test`, `cpu_jump_x0_test`, `cpu_regfile_semantics_test` | final register comparison includes x0; ALU/load writes to x0 and jump return-address discard with `rd == x0` are checked | Covered | Dedicated x0 discard cases are included. |
| RF-003 | Register Reset Value | all tests, `cpu_scoreboard`, `cpu_protocol_assertions` | x0 is checked during reset; final register compare checks architectural state | Covered | Assertion-backed x0 reset sanity plus scoreboard evidence. |
| RF-004 | Synchronous Write | all tests, `DUT_TRACE`, `cpu_regfile_assertions` | writeback appears after instruction execution; next-cycle register update is asserted | Covered | Assertion checks written register contents after a synchronous write. |
| RF-005 | Asynchronous Read | ALU/branch tests, `cpu_regfile_assertions` | dependent source reads produce expected results; read ports are asserted against addressed registers | Covered | Assertion checks read-port data against current register contents. |
| RF-006 | Dual Read Ports | ALU/branch tests | R-type and branch operations read two operands | Covered | ADD/SUB/branches require rs1 and rs2. |
| RF-007 | Single Write Port | all writeback tests | one destination writeback per instruction | Covered | Visible in `DUT_TRACE` writeback stream. |
| RF-008 | Read-During-Write | `cpu_regfile_semantics_test` | dependent and same-register instruction sequence matches reference-model state | Covered | Architectural same-register dependency behavior is directly tested. |

## 4. Instruction Fetch Requirements

| Req ID | Title | Covered by | Evidence | Status | Notes |
|---|---|---|---|---|---|
| IF-001 | Instruction Width | all tests | 32-bit instruction words in `PRELOAD STEP` and `DUT FETCH_RSP` | Covered | Every executed instruction is 32 bits. |
| IF-002 | Fetch Source | all tests, `DUT_TRACE` | instruction fetches through AXI read response | Covered | Fetch request/response trace is present. |
| IF-003 | PC Increment | `cpu_basic_alu_test`, `cpu_load_store_test`, `cpu_random_test` | sequential `PC += 4` fetches | Covered | Non-control-flow paths show aligned increments. |
| IF-004 | PC Update on Branch Taken | `cpu_branch_test` | branch skips poison instruction and fetches target PC | Covered | BEQ/BNE/BLT/BGE taken paths are shown. |
| IF-005 | PC Update on Jump | `cpu_branch_test` | JAL and JALR target fetches | Covered | JAL/JALR traces show target redirection. |
| IF-006 | Instruction Alignment | `cpu_misaligned_control_test` | misaligned branch/JAL/JALR targets assert illegal halt | Covered | Control-flow target tests prevent non-word-aligned instruction fetch continuation. |
| IF-007 | ARADDR for Fetch | all tests, `DUT_TRACE` | fetch request PC values | Covered | Trace reports fetch PC. |
| IF-008 | ARPROT for Fetch | `cpu_protocol_assertions` | instruction fetch ARPROT asserted as `3'b100` | Covered | Assertion checks fetch state ARPROT value. |
| IF-009 | Stall on Fetch Wait | `cpu_axi_wait_state_test`, `DUT_TRACE` | fetch request/response separated by inserted read wait cycles | Covered | Directed wait-state run checks final state after stalls. |
| IF-010 | No Concurrent Data Access During Fetch | all tests, `DUT_TRACE`, `cpu_protocol_assertions` | no fetch/data overlap in traces and assertions | Covered | Assertion prevents read/write valid overlap and outstanding overlap. |

## 5. Decode Requirements

| Req ID | Title | Covered by | Evidence | Status | Notes |
|---|---|---|---|---|---|
| ID-001 | Instruction Format Support | directed tests | R/I/S/B/U/J instructions generated and executed | Covered | Basic ALU, load/store, branch/JAL/JALR cover all formats. |
| ID-002 | Opcode Decode | directed tests, `cpu_reg_coverage_sweep_test`, `cpu_coverage` | opcode classes execute and scoreboards pass | Covered | Coverage tracks opcode execution, including SYSTEM as halt behavior. |
| ID-003 | Source Register Decode | ALU/load/store/branch tests, `cpu_reg_coverage_sweep_test` | source operands affect expected results | Covered | Register sweep intentionally samples uncovered `rs1` and `rs2` fields. |
| ID-004 | Destination Register Decode | ALU/load/branch tests, `cpu_reg_coverage_sweep_test` | rd writebacks match expected registers | Covered | Register sweep intentionally samples uncovered `rd` fields. |
| ID-005 | Funct3 Decode | ALU/load/store/branch tests, `cpu_coverage` | planned opcode-by-`funct3` functional coverage crosses reached closure | Covered | ALU, branch, load, and store `funct3` variants are sampled by directed regression. |
| ID-006 | Funct7 Decode | `cpu_basic_alu_test`, `cpu_invalid_decode_test`, `cpu_coverage` | ADD/SUB and SRL/SRA legal distinctions plus invalid OP/OP-IMM funct7 halt cases | Covered | Directed invalid decode cases cover illegal funct7 variants. |
| ID-007 | I-type Immediate | ALU/load/JALR tests | ADDI/ANDI/ORI/XORI/load/JALR immediates execute | Covered | Expected values match reference model. |
| ID-008 | S-type Immediate | load/store tests | store addresses and checkpoint writes match | Covered | Store effective addresses verified by memory compare. |
| ID-009 | B-type Immediate | branch test | branch targets and poison skip behavior | Covered | Branch target fetches prove immediate decode. |
| ID-010 | U-type Immediate | basic ALU test | LUI/AUIPC checkpointed values | Covered | `LUI` and `AUIPC` results are logged. |
| ID-011 | J-type Immediate | branch test | JAL target and return address | Covered | JAL trace and scoreboard evidence. |
| ID-012 | Illegal Instruction Detection | illegal instruction test | FENCE/illegal instruction halts DUT | Covered | `DUT HALT illegal_instr=1`. |

## 6. ALU Requirements

| Req ID | Title | Covered by | Evidence | Status | Notes |
|---|---|---|---|---|---|
| ALU-001 | ADD | `cpu_basic_alu_test`, `cpu_random_test` | ADD result checkpointed and scoreboard passes | Covered | Includes register and immediate add behavior with ADD/ADDI split. |
| ALU-002 | SUB | `cpu_basic_alu_test`, `cpu_random_test` | SUB result checkpointed | Covered | Directed SUB case present. |
| ALU-003 | ADDI | `cpu_basic_alu_test`, all tests setup | ADDI setup and result traces | Covered | Used heavily for setup and directed cases. |
| ALU-004 | AND / ANDI | `cpu_basic_alu_test`, `cpu_random_test` | AND/ANDI checkpointed or random-ref compared | Covered | Directed and random evidence. |
| ALU-005 | OR / ORI | `cpu_basic_alu_test`, `cpu_random_test` | OR/ORI checkpointed or random-ref compared | Covered | Directed and random evidence. |
| ALU-006 | XOR / XORI | `cpu_basic_alu_test`, `cpu_random_test` | XOR/XORI checkpointed or random-ref compared | Covered | Directed and random evidence. |
| ALU-007 | SLL / SLLI | `cpu_basic_alu_test`, `cpu_random_test` | SLL/SLLI results checkpointed | Covered | Directed shift-left cases present. |
| ALU-008 | SRL / SRLI | `cpu_basic_alu_test` | SRL/SRLI results checkpointed | Covered | Directed logical shift-right cases present. |
| ALU-009 | SRA / SRAI | `cpu_basic_alu_test` | signed right-shift results checkpointed | Covered | Negative operand case included. |
| ALU-010 | SLT | `cpu_basic_alu_test` | signed compare result checkpointed | Covered | Directed negative-vs-positive case. |
| ALU-011 | SLTU | `cpu_basic_alu_test` | unsigned compare result checkpointed | Covered | Directed unsigned negative-value case. |
| ALU-012 | SLTI | `cpu_alu_imm_corner_test` | signed immediate compare true and false cases checkpointed | Covered | Directed signed negative-vs-zero and positive-vs-zero cases are included. |
| ALU-013 | SLTIU | `cpu_alu_imm_corner_test` | unsigned immediate compare true and false cases checkpointed | Covered | Directed unsigned sign-extended immediate cases are included. |
| ALU-014 | LUI | `cpu_basic_alu_test` | LUI result checkpointed | Covered | `0xdead0000` evidence in trace. |
| ALU-015 | AUIPC | `cpu_basic_alu_test` | AUIPC result checkpointed | Covered | PC-relative result evidence in trace. |

## 7. Branch And Jump Requirements

| Req ID | Title | Covered by | Evidence | Status | Notes |
|---|---|---|---|---|---|
| BRN-001 | BEQ | `cpu_branch_test` | BEQ taken target and pass marker | Covered | Poison instruction skipped. |
| BRN-002 | BNE | `cpu_branch_test` | BNE taken target and pass marker | Covered | Poison instruction skipped. |
| BRN-003 | BLT | `cpu_branch_test` | signed BLT taken target | Covered | Negative-vs-positive branch case. |
| BRN-004 | BLTU | `cpu_branch_test`, `cpu_branch_corner_test` | unsigned BLTU not-taken and taken behavior checked | Covered | Directed branch-corner sequence adds the taken case. |
| BRN-005 | BGE | `cpu_branch_test` | signed BGE taken target | Covered | Directed taken case. |
| BRN-006 | BGEU | `cpu_branch_corner_test` | unsigned BGEU taken and not-taken behavior checked | Covered | Directed branch-corner sequence includes both outcomes. |
| BRN-007 | Branch Target Alignment | `cpu_misaligned_control_test` | taken branch to `PC+2` asserts illegal halt | Covered | Poison instruction after the misaligned branch does not execute. |
| JMP-001 | JAL | `cpu_branch_test` | JAL target and x20 return address | Covered | Return address stored to memory. |
| JMP-002 | JALR | `cpu_branch_test` | JALR target and x21 return address | Covered | Target skips poison instruction. |
| JMP-003 | JAL/JALR with rd=x0 | `cpu_jump_x0_test` | `JAL x0` and `JALR x0` skip poison instructions and leave x0 at zero | Covered | Return-address discard behavior is now directly tested. |

## 8. Memory Requirements

| Req ID | Title | Covered by | Evidence | Status | Notes |
|---|---|---|---|---|---|
| MEM-001 | LW | `cpu_load_store_test` | LW load response and writeback | Covered | Word load from checkpoint area. |
| MEM-002 | LH | `cpu_load_store_test` | LH sign-extension case | Covered | Halfword load expected `0x000007ff`. |
| MEM-003 | LHU | `cpu_load_store_test` | LHU zero-extension case | Covered | Halfword unsigned load expected `0x000007ff`. |
| MEM-004 | LB | `cpu_load_store_test` | LB sign-extension case | Covered | Byte `0xff` becomes `0xffffffff`. |
| MEM-005 | LBU | `cpu_load_store_test` | LBU zero-extension case | Covered | Byte `0xff` becomes `0x000000ff`. |
| MEM-006 | Load Lane Selection | `cpu_load_store_test` | byte/halfword lane loads | Covered | Low-address lane behavior exercised. |
| MEM-007 | SW | all directed tests | checkpoint stores with `STRB=0xf` | Covered | Memory compare confirms words. |
| MEM-008 | SH | `cpu_load_store_test` | upper-halfword store `STRB=0xc` | Covered | Word becomes `0x00630000`. |
| MEM-009 | SB | `cpu_load_store_test` | byte store `STRB=0x1` | Covered | Byte lane selected correctly. |
| MEM-010 | Store Data Placement | `cpu_load_store_test` | `DATA` and `STRB` traces for SB/SH/SW | Covered | DUT store trace shows lane placement. |
| MEM-011 | AXI4-Lite Protocol Compliance | all tests, RAM model, `cpu_protocol_assertions` | transactions complete successfully with valid-stable and serialization checks | Covered | Assertion set covers the current single-master AXI4-Lite subset. |
| MEM-012 | AXI Read for Fetch and Load | all tests, load/store test | fetch/load read traces | Covered | `FETCH_REQ/RSP` and `LOAD_REQ/RSP`. |
| MEM-013 | AXI Write for Store | all store tests | store request/response traces | Covered | `STORE_REQ/RSP` visible. |
| MEM-014 | AXI Write Strobe | `cpu_load_store_test` | `STRB=0xf`, `0x3`, `0x1`, `0xc` | Covered | Word, halfword, byte lanes tested. |
| MEM-015 | Stall on Memory Wait | `cpu_axi_wait_state_test`, `DUT_TRACE` | load/store request/response sequencing with inserted wait cycles | Covered | Directed wait-state test checks final memory/register state. |
| MEM-016 | ARPROT for Data | `cpu_protocol_assertions` | data-read ARPROT asserted as `3'b000` | Covered | Assertion checks data load state ARPROT value. |
| MEM-017 | AWPROT for Data | `cpu_protocol_assertions` | data-write AWPROT asserted as `3'b000` | Covered | Assertion checks data store state AWPROT value. |
| MEM-018 | Word Alignment | `cpu_misaligned_access_test` | unaligned LW/SW cases assert illegal halt | Covered | Poison instruction after each misaligned word access does not execute. |
| MEM-019 | Halfword Alignment | `cpu_misaligned_access_test` | unaligned LH/SH cases assert illegal halt | Covered | Poison instruction after each misaligned halfword access does not execute. |
| MEM-020 | Byte Access Alignment | `cpu_load_store_test` | byte access at byte address succeeds | Covered | SB/LB/LBU lane behavior exercised. |
| MEM-021 | No Concurrent Fetch and Data Access | all tests, `DUT_TRACE`, `cpu_protocol_assertions` | serialized fetch/data traces and no-overlap assertions | Covered | Assertion prevents read/write overlap. |
| MEM-022 | Transaction Serialization | all tests, `DUT_TRACE`, `cpu_protocol_assertions` | one transaction completes before next | Covered | Assertion tracks read and write outstanding state. |
| MEM-023 | Read Response Check | `cpu_axi_error_test` | fetch and load RRESP error injection asserts illegal halt | Covered | RAM model injects SLVERR for fetch and data-read cases. |
| MEM-024 | Write Response Check | `cpu_axi_error_test` | store BRESP error injection asserts illegal halt | Covered | RAM model injects SLVERR for the store response case. |

## 9. Exception Requirements

| Req ID | Title | Covered by | Evidence | Status | Notes |
|---|---|---|---|---|---|
| EXC-001 | Illegal Instruction Trap | `cpu_illegal_instr_test`, all tests halt instruction | `DUT HALT illegal_instr=1` | Covered | Intentional illegal instruction ends programs. |
| EXC-002 | Illegal Instruction Halt | `cpu_illegal_instr_test` | poison instruction after illegal halt does not execute | Covered | Explicit pass message and scoreboard match. |
| EXC-003 | Misaligned Instruction Fetch | `cpu_misaligned_control_test` | misaligned branch/JAL/JALR targets assert illegal halt | Covered | CPU halts before continuing from a non-word-aligned target. |
| EXC-004 | Misaligned Memory Access | `cpu_misaligned_access_test` | unaligned word and halfword load/store cases assert illegal halt | Covered | LW/SW/LH/SH misalignment cases are directed. |
| EXC-005 | Bus Error Handling | `cpu_axi_error_test` | AXI fetch, load, and store response errors assert illegal halt | Covered | Read and write response error paths are directed. |

## 10. Summary

| Status | Count |
|---|---:|
| Covered | 95 |
| TODO | 0 |
| Planned | 0 |
| Total | 95 |

The highest-priority planned closures are:

1. DUT code coverage closure for remaining `cpu_tb_top.u_cpu` expression, toggle, and FSM-transition holes.
2. Broader protocol checker coverage if the AXI interface grows beyond the current single-master subset.
3. Coverage-directed random generation for remaining reachable RTL holes.

`cpu_branch_unit_force_test` is intentionally tracked as defensive code coverage evidence only. Legal ISA execution cannot generate the invalid branch-op value because decoder logic blocks it before it reaches `u_branch_unit`.
