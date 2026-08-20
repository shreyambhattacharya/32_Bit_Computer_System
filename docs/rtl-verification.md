# RTL Verification Strategy

Mini32 uses the C++ simulator as its golden architectural reference and SystemVerilog as the synthesizable hardware implementation. Differential verification is a major design goal, but its full infrastructure follows the RTL CPU core.

## Layer 1 — module tests

Self-checking SystemVerilog testbenches cover the ALU, register file, immediate generator, decoder, control unit, multi-cycle CPU core, 64 KiB ROM, 64 KiB RAM, UART, Timer, GPIO, Debug, and the system bus. Timer tests cover post-retirement enable ordering, match, wraparound, and disable; GPIO tests cover external input plus output/direction latches. Bus tests cover routing and non-executable Timer/GPIO fetches.

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

Each retirement compares PC, instruction, next PC, committed register change, and committed store. Final records compare HALT or fault state, detailed fault metadata, UART, Debug VALUE, GPIO OUTPUT/DIRECTION, and Timer COUNTER/COMPARE/CONTROL. Accepted hexadecimal fields are case-insensitive and normalized to lowercase before comparison. This intentionally does not compare cycles, FSM state, bus timing, or private datapath signals.

## Layer 3 — peripheral system equivalence

Peripheral-state comparison is implemented through `hello_uart.asm`, `debug_demo.asm`, `peripheral_readback.asm`, `gpio_demo.asm`, and `timer_demo.asm`. The Timer uses retirement events rather than raw simulation cycles, so its final state is an architectural equivalence check.
