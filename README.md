# Mini Computer

Mini Computer is a hardware-oriented software model of a compact, custom 32-bit RISC computer. The first delivery is a deterministic multi-cycle C++ simulator and Python assembler; its module boundaries and timing model are chosen to transfer cleanly to future SystemVerilog/FPGA work.

## Project status

The complete Mini32 v0.1 CPU, Python assembler/disassembler, UART, Debug MMIO peripheral, and standalone simulator are implemented and tested together. Timer/GPIO, STM32 integration, and an interactive monitor/debugger remain unimplemented.

## Design choices

- 32-bit fixed-width instructions and 32-bit byte-addressable addresses/data.
- 32 general-purpose registers; `r0` always reads as zero and discards writes.
- Multi-cycle control (`FETCH`, `DECODE`, `EXECUTE`, `MEMORY`, `WRITEBACK`) so a future FPGA can use synchronous memory.
- Little-endian memory and initially aligned 32-bit instruction/data accesses.
- Memory-mapped peripherals, so programs use normal loads/stores for I/O.

See [architecture](docs/architecture.md), [ISA](docs/isa.md), and [memory map](docs/memory-map.md).

## Build and test

When implementation begins:

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

## Layout

- `simulator/` — C++ modules corresponding to future hardware blocks.
- `assembler/` — Python custom-ISA assembler.
- `programs/` — assembly integration programs.
- `tests/` — unit and end-to-end regression tests.
- `firmware/stm32/` — later STM32 peripheral-controller firmware.
- `docs/` — architecture contracts that implementation must follow.

## Future scope

Timer/GPIO MMIO, a monitor/debugger, the STM32 bridge, interrupts, ROM monitor/kernel, byte load/store, a pipeline, and initial SystemVerilog modules are later milestones.

The STM32 bridge remains an integration milestone, not a prerequisite for validating the computer itself.
