# RTL Verification Strategy

Mini32 uses the C++ simulator as its golden architectural reference and SystemVerilog as the synthesizable hardware implementation. Differential verification is a major design goal, but its full infrastructure follows the RTL CPU core.

## Layer 1 — module tests

Self-checking SystemVerilog testbenches cover the ALU, register file, immediate generator, decoder, control unit, multi-cycle CPU core, 64 KiB ROM, 64 KiB RAM, UART MMIO, Debug MMIO, and the system bus. The UART bench checks deterministic reads and distinct DATA events; the Debug bench checks reset, persistence, readback, and inert reserved registers. Bus tests cover one-completion handshakes, reset cancellation, permissions, alignment, UART/Debug routing, unmapped ranges, and single-write stores. A Python test validates raw-image to `.memh` little-endian conversion and malformed/oversized rejection.

`tb_mini32_system.sv` instantiates the real `mini32_system`, not behavioral memories. It additionally boots `hello_uart.asm` and `peripheral_readback.asm`; it checks the 14 UART events in `Hello Mini32!\n`, Debug VALUE persistence, UART STATUS readback, and Debug VALUE readback through retired register writes.

## Layer 2 — retirement-boundary differential simulation

The same assembly source is assembled once to one raw `.bin`. `mini32_ref_trace` executes that binary through `CpuCore::step()` and derives effects from pre/post architectural state; `bin_to_mem.py` converts the same binary to `.memh`; `tb_differential_trace.sv` boots it through the real RTL system. Both produce JSONL records, and `verification/differential.py` compares them in retirement order.

```text
program.asm → assembler.py → program.bin ──→ C++ reference trace
                                  │
                                  └→ bin_to_mem.py → program.memh → RTL system → RTL trace
                                                                  \              /
                                                                   └→ comparator ┘
```

Each retirement compares PC, instruction, next PC, committed register change, and committed store. Final records compare HALT or fault state, detailed fault metadata, the UART byte stream, and Debug VALUE. Accepted hexadecimal fields are case-insensitive and normalized to lowercase before comparison. This intentionally does not compare cycles, FSM state, bus timing, or private datapath signals.

## Layer 3 — peripheral system equivalence

The peripheral-state comparison is implemented: `hello_uart.asm`, `debug_demo.asm`, and `peripheral_readback.asm` remain common guest stimuli across the Python assembler, C++ model, and RTL system.
