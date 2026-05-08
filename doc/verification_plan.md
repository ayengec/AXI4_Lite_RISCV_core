# RV32I AXI4-Lite Subsystem Verification Plan

## 1. Purpose

This document defines the verification strategy for `rv32i_axi4l_subsystem_uvm_tb`.

The goal is to verify that the RV32I CPU subsystem satisfies the hardware requirements in `doc/reqs.md` using a self-checking UVM environment, directed tests, constrained-random stimulus, reference-model comparison, scoreboard checks, and coverage analysis.

## 2. Verification Scope

### In Scope

| Area | Scope |
|---|---|
| RV32I base integer execution | Supported ALU, branch, jump, load/store, and upper-immediate instructions |
| Register file behavior | x0 behavior, register reset, read/write behavior, architectural state updates |
| Instruction fetch | reset vector fetch, PC increment, control-flow PC updates, fetch alignment |
| Decode | opcode, `funct3`, `funct7`, immediate extraction, illegal decode detection |
| ALU | arithmetic, logical, shift, compare, LUI, AUIPC behavior |
| Branch and jump | taken/not-taken branches, JAL, JALR, target calculation, return address writeback |
| Memory access | load/store widths, sign/zero extension, byte lane selection, write strobes |
| AXI4-Lite behavior | serialized instruction/data transactions through one master interface |
| Exception behavior | unsupported instruction, misaligned access, bus error, and halt behavior |
| Coverage | functional coverage and code coverage closure tracking |

### Out Of Scope

| Area | Reason |
|---|---|
| Pipelining | CPU revision is non-pipelined |
| Branch prediction | CPU revision uses direct control-flow update |
| Caches | CPU revision accesses memory through AXI4-Lite directly |
| Interrupts, privilege modes, CSRs | not implemented in this revision |
| Multiple outstanding AXI transactions | explicitly out of scope |
| AXI bursts | AXI4-Lite does not support burst transactions |
| Multiply/divide and compressed instructions | not part of RV32I base subset implemented here |

## 3. Verification Strategy

The environment uses a program-based verification strategy:

1. A UVM sequence builds an ordered RV32I instruction stream.
2. The test preloads the instruction stream into the RAM model through a testbench backdoor.
3. The reference model executes the same program and produces expected register and memory state.
4. Reset is released and the RTL CPU fetches the program through AXI4-Lite.
5. The DUT trace monitor logs fetch, load, store, writeback, and halt activity.
6. The scoreboard compares DUT registers and memory against the reference model.
7. Functional and code coverage are collected for closure analysis.

The debug log is intentionally aligned with this flow:

| Log tag | Verification meaning |
|---|---|
| `PRELOAD STEP` | sequence generated this instruction and wrote it into instruction memory |
| `REF STEP` | reference model executed this instruction and calculated expected state |
| `DUT_TRACE` | RTL executed observable fetch/load/store/writeback/halt behavior |
| `cpu_scoreboard` | final DUT architectural state matched or mismatched the reference model |

## 4. Testbench Architecture

| Component | Role |
|---|---|
| `cpu_tb_top` | top-level module, clock/reset, DUT instance, RAM model, trace monitor |
| `cpu_tb_if` | virtual interface used by UVM components to control reset and access testbench services |
| `axi4lite_ram` | AXI4-Lite memory model used for instruction fetch and data access |
| `cpu_base_seq` | base instruction stream builder and instruction metadata storage |
| directed sequences | build deterministic programs for ALU, load/store, and branch/jump features |
| `cpu_random_prog_seq` | builds randomized valid RV32I programs |
| `cpu_ref_model` | lightweight RV32I ISS used as the golden model |
| `cpu_scoreboard` | compares final DUT register and data-memory state against the reference model |
| `cpu_coverage` | samples executed instructions for functional coverage |
| `cpu_protocol_assertions` | checks reset sanity, AXI protection bits, valid-stable behavior, and serialized single-outstanding access |
| `cpu_regfile_assertions` | checks synchronous write update, x0 stability, and register read-port consistency |

## 5. Test Plan

| Test | Primary purpose | Requirement areas | Expected result |
|---|---|---|---|
| `cpu_basic_alu_test` | directed ALU and immediate operation checking | RF, IF, ID, ALU, MEM, EXC | ALU results are written back and checkpointed to memory; scoreboard passes |
| `cpu_alu_imm_corner_test` | directed `SLTI` and `SLTIU` immediate compare corner cases | RF, ID, ALU, MEM, EXC | signed and unsigned immediate compare results are checkpointed and scoreboards pass |
| `cpu_load_store_test` | load/store width, sign extension, zero extension, and byte lane checking | RF, IF, ID, MEM, AXI, EXC | loaded values and memory checkpoint words match the reference model |
| `cpu_branch_test` | branch, jump, JALR, return address, and poison-instruction skip checking | IF, ID, BRN, JMP, MEM, EXC | correct branch targets are fetched and skipped instructions do not affect state |
| `cpu_branch_corner_test` | directed unsigned branch corner coverage | IF, ID, BRN, MEM, EXC | `BLTU` and `BGEU` taken/not-taken outcomes match the reference model |
| `cpu_jump_x0_test` | directed jump return-address discard coverage | RF, IF, ID, JMP, MEM, EXC | `JAL x0` and `JALR x0` redirect control flow without changing x0 |
| `cpu_reg_coverage_sweep_test` | targeted register-field and SYSTEM opcode functional coverage closure | RF, ID, ALU, EXC | uncovered `rd`, `rs1`, `rs2`, and `SYSTEM` opcode bins are intentionally sampled |
| `cpu_mem_lane_sweep_test` | directed byte/halfword lane coverage closure | ID, MEM, AXI | byte and halfword lanes are exercised across address offsets |
| `cpu_regfile_semantics_test` | directed x0 discard and dependent register-read coverage | RF, ID, ALU, MEM | write-to-x0 and dependent read/write behavior match the reference model |
| `cpu_address_boundary_test` | directed implemented address boundary checking | SYS, MEM, AXI | store/load at the upper implemented RAM word address works and checkpoints through the scoreboard window |
| `cpu_misaligned_access_test` | directed misaligned load/store halt checking | MEM, EXC | misaligned LW/SW/LH/SH cases assert illegal halt before poison execution |
| `cpu_misaligned_control_test` | directed misaligned branch/jump target halt checking | IF, BRN, JMP, EXC | misaligned branch, JAL, and JALR targets assert illegal halt |
| `cpu_invalid_decode_test` | directed invalid decode/code-coverage cases | ID, EXC | invalid encodings halt cleanly and do not execute poison instructions |
| `cpu_axi_wait_state_test` | directed AXI wait-state checking | SYS, IF, MEM, AXI | fetch/data transactions complete correctly with inserted read/write wait cycles |
| `cpu_axi_error_test` | directed AXI response error checking | MEM, AXI, EXC | fetch, load, and store response errors assert illegal halt |
| `cpu_branch_unit_force_test` | defensive branch-unit default coverage | code coverage only | `uvm_hdl_force` drives the unreachable invalid `branch_op_i` value and confirms `branch_taken_o=0` |
| `cpu_illegal_instr_test` | unsupported instruction halt behavior | ID, EXC, MEM | DUT asserts halt behavior and does not execute the poison instruction |
| `cpu_random_test` | randomized valid program stress | RF, IF, ID, ALU, MEM subset | reference model and DUT final state match |

## 6. Requirement-To-Test Strategy

The requirement document is grouped by UID prefixes. The verification strategy maps those groups to tests and checkers as follows:

| Requirement group | Verification approach |
|---|---|
| `SYS-*` | reset behavior, serialized operation, and final halt/pass behavior checked in all tests |
| `RF-*` | register writeback, final register comparison, and register-file assertions |
| `IF-*` | fetch PC, PC increment, branch/jump PC updates, fetch trace, and fetch AXI assertions |
| `ID-*` | directed instruction encodings plus reference model execution and illegal-instruction tests |
| `ALU-*` | `cpu_basic_alu_test`, `cpu_alu_imm_corner_test`, and random ALU programs |
| `BRN-*` | `cpu_branch_test` and `cpu_branch_corner_test` directed taken/not-taken branch scenarios |
| `JMP-*` | `cpu_branch_test` and `cpu_jump_x0_test` directed JAL/JALR scenarios |
| `MEM-*` | `cpu_load_store_test`, `cpu_mem_lane_sweep_test`, `cpu_misaligned_access_test`, and AXI protocol assertions |
| `EXC-*` | `cpu_illegal_instr_test`, `cpu_misaligned_access_test`, `cpu_misaligned_control_test`, and `cpu_axi_error_test` halt/error scenarios |

A UID-level traceability matrix is maintained separately in `doc/traceability.md`.

## 7. Functional Coverage Plan

Functional coverage is collected from executed instructions sampled by `cpu_coverage`.

| Coverage item | Intent |
|---|---|
| opcode coverage | confirm each supported instruction class is executed |
| `funct3` coverage | confirm operation variants for ALU, branch, load, and store groups |
| `funct7` coverage | distinguish encodings such as ADD/SUB and SRL/SRA |
| source register coverage | confirm `rs1` and `rs2` usage across the register file |
| destination register coverage | confirm `rd` usage across the register file |
| opcode by `funct3` crosses | confirm legal decode/execute combinations |
| load/store width coverage | confirm byte, halfword, and word memory operations |
| branch direction coverage | confirm taken and not-taken branch behavior |

Functional coverage closure goal:

- current version: reached `100%` functional coverage for the planned RV32I subset after directed closure tests
- next version: keep functional coverage at `100%` as new requirements, tests, and coverpoints are added

## 8. Code Coverage Plan

Code coverage is collected during regression runs at the DUT instance level: `cpu_tb_top.u_cpu`.

The closure metric uses the cumulative view of `cpu_tb_top.u_cpu`, including the CPU RTL and its children. Testbench code, UVM components, RAM model code, and debug helper code are not used as the project code-coverage target.

| Coverage type | Closure intent |
|---|---|
| block coverage | execute all reachable RTL control blocks |
| expression coverage | exercise meaningful expression outcomes |
| toggle coverage | toggle relevant datapath and control signals |
| FSM state coverage | reach all legal CPU FSM states |
| FSM transition coverage | exercise all legal CPU FSM transitions |

Code coverage closure goal:

- current version: identify remaining reachable RTL holes under `cpu_tb_top.u_cpu`
- next version: push DUT code coverage close to `100%` for reachable design logic

Some defensive RTL defaults are not reachable through legal ISA execution because the decoder blocks the invalid control value before it reaches the downstream unit. `cpu_branch_unit_force_test` is kept separate from architectural tests and uses `uvm_hdl_force` only to cover the branch-unit default branch-op case. It is evidence for defensive code coverage, not a normal requirement-level branch behavior test.

Unreachable code should be reviewed before exclusion. Exclusions should be justified by requirement scope or intentionally unsupported functionality.

## 9. Pass / Fail Criteria

A test passes only when all applicable criteria are met:

| Criterion | Required result |
|---|---|
| UVM errors | `UVM_ERROR` count is `0` |
| UVM fatals | `UVM_FATAL` count is `0` |
| register compare | all 32 architectural registers match the reference model |
| memory compare | checked data-memory window matches the reference model |
| halt behavior | CPU halts only when the test expects halt |
| illegal instruction behavior | `illegal_instr` behavior matches test expectation |
| timeout | test completes before timeout |

For coverage closure runs, merged coverage must also meet the project coverage target for that milestone.

## 10. Regression Strategy

The standard regression contains:

```text
cpu_basic_alu_test
cpu_alu_imm_corner_test
cpu_load_store_test
cpu_branch_test
cpu_branch_corner_test
cpu_jump_x0_test
cpu_reg_coverage_sweep_test
cpu_mem_lane_sweep_test
cpu_regfile_semantics_test
cpu_address_boundary_test
cpu_misaligned_access_test
cpu_misaligned_control_test
cpu_invalid_decode_test
cpu_axi_wait_state_test
cpu_axi_error_test
cpu_branch_unit_force_test
cpu_illegal_instr_test
cpu_random_test
```

Recommended execution strategy:

1. Compile/elaborate the testbench once.
2. Run each test from the compiled snapshot.
3. Collect per-test coverage databases.
4. Merge coverage in the local IMC/Xcelium environment.
5. Review failures before reviewing coverage.
6. Use uncovered functional bins and code coverage holes to define the next directed tests.

## 11. Current Known Gaps

| Gap | Planned closure direction |
|---|---|
| UID-level traceability needs maintenance | keep `doc/traceability.md` updated as tests and coverage closure improve |
| functional coverage maintenance | keep merged functional coverage at `100%` as new coverpoints or requirements are added |
| DUT code coverage is not yet near 100% | add directed tests for missing expressions, toggles, and FSM transitions under `cpu_tb_top.u_cpu` |
| AXI protocol checking can be extended further | add broader AXI4-Lite checker coverage if the interface grows beyond the current single-master subset |
| defensive default handling needs review | classify remaining default branches as reachable by test, force-only defensive coverage, or intentionally unreachable |
| random generation is not coverage-directed yet | bias random generation toward uncovered opcodes, registers, and crosses |

## 12. Planned Next Tests

| Planned test | Purpose |
|---|---|
| `cpu_branch_not_taken_test` | explicit not-taken coverage for every branch condition |
| coverage-directed random test | randomized programs biased by remaining code coverage holes |

## 13. Documentation Outputs

| Document | Purpose |
|---|---|
| `doc/reqs.md` | hardware requirements |
| `doc/verification_plan.md` | strategy for verifying the requirements |
| `doc/traceability.md` | UID-level requirement-to-test matrix |
| `doc/coverage_closure_plan.md` | planned uncovered-bin and code-coverage closure tracker |
| `my_run_logs/regression_trace_examples.md` | sanitized example evidence from regression logs |
