# RTL Verification Strategy

Mini32 uses the C++ simulator as its golden architectural reference and SystemVerilog as the synthesizable hardware implementation. Differential verification is a major design goal, but its full infrastructure follows the RTL CPU core.

## Layer 1 — module tests

Self-checking SystemVerilog testbenches cover the ALU, register file, immediate generator, decoder, control unit, multi-cycle CPU core, 64 KiB ROM, 64 KiB RAM, and the system bus. ROM/RAM tests cover first/middle/final words, synchronous behavior, persistence, and non-aliasing. Bus tests cover one-completion handshakes, reset cancellation, permissions, alignment, unmapped ranges, and single-write stores. A Python test validates raw-image to `.memh` little-endian conversion and malformed/oversized rejection.

`tb_mini32_system.sv` instantiates the real `mini32_system`, not behavioral memories. It assembles and boots `memory_roundtrip.asm`, `rtl_system_smoke.asm`, and `rtl_system_fault.asm`; its checks use propagated retirement traces, halt/fault state, and real bus fault mapping. The smoke image proves arithmetic, RAM stores/loads, a loop branch, and HALT. The fault image proves an assembled unmapped `LW` becomes `CPU_FAULT_UNMAPPED_LOAD`.

## Layer 2 — CPU equivalence

The next step is automated execution of the same assembled ROM image on the C++ golden model and the complete RTL system. Tests will compare retirement traces, registers, PC, RAM, and halt/fault outcomes.

## Layer 3 — system equivalence

After RTL peripherals exist, tests will additionally compare UART output, Debug MMIO value, RAM, and program completion. Guest programs remain the common stimulus across the Python assembler, C++ model, and RTL system.
