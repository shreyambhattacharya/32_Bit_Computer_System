# RTL Verification Strategy

Mini32 uses the C++ simulator as its golden architectural reference and SystemVerilog as the synthesizable hardware implementation. Differential verification is a major design goal, but its full infrastructure follows the RTL CPU core.

## Layer 1 — module tests

Self-checking SystemVerilog testbenches cover the ALU, register file, immediate generator, decoder, and control unit. They validate architectural edge cases, field extraction, canonical encodings, and control signals without a CPU core.

## Layer 2 — CPU equivalence

After `cpu_core.sv` exists, the same assembled ROM image will run on the C++ golden model and RTL CPU. Tests will compare registers, PC, RAM, and halt/fault outcomes.

## Layer 3 — system equivalence

After RTL bus and peripherals exist, tests will additionally compare UART output, Debug MMIO value, RAM, and program completion. Guest programs remain the common stimulus across the Python assembler, C++ model, and RTL system.
