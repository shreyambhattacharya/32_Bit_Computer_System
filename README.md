# Mini Computer

Mini Computer is a hardware-oriented software model of a compact, custom 32-bit RISC computer. The first delivery is a deterministic multi-cycle C++ simulator and Python assembler; its module boundaries and timing model are chosen to transfer cleanly to future SystemVerilog/FPGA work.

## Project status

The complete Mini32 v0.1 machine-code ISA executes through the tested multi-cycle CPU controller, including arithmetic, logical operations, ROM/RAM access, branches, jumps, calls, returns, and `HALT`. The assembler, disassembler, MMIO peripherals, and STM32 integration remain unimplemented.

## Design choices

- 32-bit fixed-width instructions and 32-bit byte-addressable addresses/data.
- 32 general-purpose registers; `r0` always reads as zero and discards writes.
- Multi-cycle control (`FETCH`, `DECODE`, `EXECUTE`, `MEMORY`, `WRITEBACK`) so a future FPGA can use synchronous memory.
- Little-endian memory and initially aligned 32-bit instruction/data accesses.
- Memory-mapped peripherals, so programs use normal loads/stores for I/O.

See [architecture](docs/architecture.md), [ISA](docs/isa.md), and [memory map](docs/memory-map.md).

## Planned workflow

When implementation begins:

```powershell
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

CTest runs ALU, register-file, decoder, ROM/bus, RAM, arithmetic CPU, data-memory CPU, and control-flow CPU tests.

## Layout

- `simulator/` — C++ modules corresponding to future hardware blocks.
- `assembler/` — Python custom-ISA assembler.
- `programs/` — assembly integration programs.
- `tests/` — unit and end-to-end regression tests.
- `firmware/stm32/` — later STM32 peripheral-controller firmware.
- `docs/` — architecture contracts that implementation must follow.

## Six-week scope

Required: simulator, assembler, ROM/RAM/bus, UART/timer/GPIO MMIO, monitor, tests, and a documented STM32 protocol. Optional: a working serial bridge to the STM32. Stretch: interrupts, ROM monitor/kernel, byte load/store, pipeline, and initial SystemVerilog modules.

The STM32 bridge remains an integration milestone, not a prerequisite for validating the computer itself.
