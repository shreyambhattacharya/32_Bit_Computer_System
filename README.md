# Mini Computer

Mini Computer is a mixed hardware/software implementation of a compact, custom 32-bit RISC computer. The Python toolchain produces Mini32 ROM images; the C++ simulator is the golden architectural reference; SystemVerilog is the synthesizable hardware implementation.

## Project status

The complete Mini32 v0.1 C++ reference CPU, Python assembler/disassembler, and synthesizable CPU/ROM/RAM/MMIO RTL are implemented and tested together. GPIO and a deterministic Timer join UART and Debug as architecturally visible peripherals. A vendor-independent FPGA platform layer adds reset synchronization and a buffered physical 8N1 UART TX pin. The Sipeed Tang Nano 20K target now has its board wrapper, constraints, Gowin project, and UART/LED bring-up image, and the complete design has passed Gowin synthesis, place-and-route, resource validation, and timing closure at 27 MHz. Post-route Fmax is 68.976 MHz. Physical board programming and validation remain the next milestone. The Timer counts successfully retired Mini32 instructions rather than wall-clock or FPGA cycles, allowing exact C++ ↔ RTL differential verification of its state.

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

UART lives at `0x20000000–0x2000000F`. Writing `DATA` (`+0x00`) transmits its low byte; `STATUS` (`+0x04`) always returns `TX_READY = 1`; DATA reads return zero. GPIO at `0x20000200–0x2000020F` exposes external INPUT, OUTPUT, and DIRECTION latches. Timer at `0x20000100–0x2000010F` counts successful retired instructions when enabled. Debug lives at `0x20000300–0x2000030F`; its `VALUE` register (`+0x00`) is a reset-zero 32-bit read/write host-visible value.

## Implementations

### C++ reference model

`simulator/` is the deterministic golden model for instruction semantics, state transitions, faults, MMIO behavior, and integration tests. CMake builds this model and its tests; it is not the final hardware implementation.

### SystemVerilog RTL

`rtl/` contains vendor-independent synthesizable hardware modules and self-checking module testbenches. It has an independent RTL-oriented Makefile workflow and is not compiled by CMake. The future FPGA hosts this digital logic; the Raspberry Pi remains a development, simulation, programming, terminal, and debug companion rather than a replacement for it.

The RTL image flow is `programs/*.asm → assembler → raw .bin → rtl/tools/bin_to_mem.py → .memh → rom.sv → mini32_system`. Run `cd rtl; make test` for RTL benches, or `python verification/differential.py --suite` after the CMake build for C++ ↔ RTL retirement-trace comparison.

`mini32_fpga_platform` is the vendor-independent physical wrapper: it synchronizes an external active-low reset, queues the architectural UART byte events, and serializes them onto a one-bit 8N1 `uart_tx` signal. Its `CLOCK_HZ`, `UART_BAUD`, and FIFO-depth parameters are board-agnostic defaults. GPIO remains separate input/output/direction signals until a board wrapper maps pins. See [FPGA platform](docs/fpga-platform.md).

The selected board target is the [Sipeed Tang Nano 20K](docs/tang-nano-20k.md). Its wrapper keeps clock, reset/button polarity, UART pin, active-low LEDs, constraints, and Gowin project configuration outside the generic RTL.

### Toolchain

`assembler/` contains the Python assembler and disassembler used to produce the same ROM images for C++ and, later, RTL simulation.

## Layout

```text
Mini32
├── assembler/   Python assembler and disassembler
├── simulator/   C++ golden reference model
├── rtl/         SystemVerilog hardware implementation
├── fpga/        board-specific wrappers, constraints, and FPGA projects
├── programs/    shared guest-program inputs
├── tests/       C++ and Python regression tests
└── docs/        architectural and verification contracts
```

- `simulator/` — C++ modules corresponding to future hardware blocks.
- `assembler/` — Python custom-ISA assembler.
- `programs/` — assembly integration programs.
- `tests/` — unit and end-to-end regression tests.
- `rtl/` — synthesizable SystemVerilog hardware modules and module-level testbenches.
- `fpga/` — isolated board/vendor integration; currently the Tang Nano 20K target.
- `firmware/stm32/` — later STM32 peripheral-controller firmware.
- `docs/` — architecture contracts that implementation must follow.

## Roadmap

1. Complete — architecture and C++ reference CPU.
2. Complete — Python assembler/disassembler.
3. Complete — C++ UART/Debug MMIO and standalone simulator.
4. Complete — RTL foundation and multi-cycle `cpu_core.sv`.
5. Complete — synthesizable ROM/RAM/system bus/top-level RTL and assembled-ROM execution.
6. Complete — automated C++ golden-model ↔ RTL retirement-trace differential simulation.
7. Complete — synthesizable UART/Debug MMIO RTL and peripheral-state differential checks.
8. Complete — GPIO MMIO and deterministic retired-instruction Timer MMIO.
9. Complete — physical UART TX serializer, platform FIFO, reset synchronizer, generic FPGA wrapper, and Linux CI.
10. Complete — Tang Nano 20K board target, pin mapping, 27 MHz clock/reset adaptation, constraints, Gowin synthesis and place-and-route, resource validation, 68.976 MHz post-route Fmax, and timing closure at 27 MHz.
11. Next — program the physical Tang Nano 20K and validate S1 reset, 115200 8N1 UART output, GPIO LEDs, the HALT LED, and fault/UART-overflow indication.
12. Stretch/future — UART RX, interrupts, optional SDRAM expansion, STM32 bridge, Raspberry Pi host-tooling enhancements, and a future RISC-V extension.

The current 64 KiB ROM plus 64 KiB RAM implementation fits using 34 of 46 BSRAM blocks, so Mini32 v0.1 does not require SDRAM. The STM32 bridge remains a later physical-integration milestone. A Raspberry Pi 5 remains useful as the development and debug host, but does not replace the FPGA logic.
