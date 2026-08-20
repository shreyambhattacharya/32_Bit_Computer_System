# Mini Computer

Mini Computer is a mixed hardware/software implementation of a compact, custom 32-bit RISC computer. The Python toolchain produces Mini32 ROM images; the C++ simulator is the golden architectural reference; SystemVerilog is the synthesizable hardware implementation.

## Project status

The complete Mini32 v0.1 C++ reference CPU, Python assembler/disassembler, UART/Debug MMIO models, and standalone simulator are implemented and tested together. Synthesizable SystemVerilog foundation modules (package, ALU, register file, immediate generator, decoder, and control unit) have begun; the full RTL CPU core is next.

## Design choices

- 32-bit fixed-width instructions and 32-bit byte-addressable addresses/data.
- 32 general-purpose registers; `r0` always reads as zero and discards writes.
- Multi-cycle control (`FETCH`, `DECODE`, `EXECUTE`, `MEMORY`, `WRITEBACK`) so a future FPGA can use synchronous memory.
- Little-endian memory and initially aligned 32-bit instruction/data accesses.
- Memory-mapped peripherals, so programs use normal loads/stores for I/O.

See [architecture](docs/architecture.md), [ISA](docs/isa.md), and [memory map](docs/memory-map.md).

## Build and test

Build and test the C++ reference model:

```powershell
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

CTest runs ALU, register-file, decoder, ROM/bus, RAM, CPU, MMIO, assembled-program integration, Python assembler/disassembler, and simulator CLI integration tests. Python 3 is required for toolchain tests and generated sample ROM images.

## Assemble and run a program

```powershell
python assembler/assembler.py programs/hello_uart.asm -o build/hello_uart.bin
.\build\mini32_sim.exe build\hello_uart.bin
```

The workflow is `assembly source → raw ROM image → mini32_sim → CpuCore → Bus → MMIO`. `mini32_sim <rom-image> [--max-instructions N]` has a default limit of 1,000,000 retired instructions. Guest UART bytes are written only to stdout; host diagnostics, faults, and the halt summary are written to stderr. It exits zero on `HALT`, and nonzero for a guest fault, invalid CLI/image, or an instruction-limit expiry.

UART lives at `0x20000000–0x2000000F`. Writing `DATA` (`+0x00`) transmits its low byte; `STATUS` (`+0x04`) always returns `TX_READY = 1`; DATA reads return zero. RX, FIFOs, interrupts, and host stdin are intentionally not implemented. Debug lives at `0x20000300–0x2000030F`; its `VALUE` register (`+0x00`) is a reset-zero 32-bit read/write host-visible value. Its `COMMAND` and reserved registers are deterministic no-ops.

## Implementations

### C++ reference model

`simulator/` is the deterministic golden model for instruction semantics, state transitions, faults, MMIO behavior, and integration tests. CMake builds this model and its tests; it is not the final hardware implementation.

### SystemVerilog RTL

`rtl/` contains vendor-independent synthesizable hardware modules and self-checking module testbenches. It has an independent RTL-oriented Makefile workflow and is not compiled by CMake. The future FPGA hosts this digital logic; the Raspberry Pi remains a development, simulation, programming, terminal, and debug companion rather than a replacement for it.

### Toolchain

`assembler/` contains the Python assembler and disassembler used to produce the same ROM images for C++ and, later, RTL simulation.

## Layout

```text
Mini32
├── assembler/   Python assembler and disassembler
├── simulator/   C++ golden reference model
├── rtl/         SystemVerilog hardware implementation
├── programs/    shared guest-program inputs
├── tests/       C++ and Python regression tests
└── docs/        architectural and verification contracts
```

- `simulator/` — C++ modules corresponding to future hardware blocks.
- `assembler/` — Python custom-ISA assembler.
- `programs/` — assembly integration programs.
- `tests/` — unit and end-to-end regression tests.
- `rtl/` — synthesizable SystemVerilog hardware modules and module-level testbenches.
- `firmware/stm32/` — later STM32 peripheral-controller firmware.
- `docs/` — architecture contracts that implementation must follow.

## Roadmap

1. Complete — architecture and C++ reference CPU.
2. Complete — Python assembler/disassembler.
3. Complete — C++ UART/Debug MMIO and standalone simulator.
4. Current — RTL foundation: package, ALU, register file, decoder, immediate generator, and control unit.
5. Next — multi-cycle `cpu_core.sv`.
6. Future — ROM/RAM/bus RTL, full ISA/control-flow RTL with differential tests, UART/GPIO/timer RTL, STM32 bridge, and FPGA synthesis/board integration.

The STM32 bridge remains a later physical-integration milestone. A Raspberry Pi 5 remains useful as the development and debug host, but does not replace the FPGA logic.
