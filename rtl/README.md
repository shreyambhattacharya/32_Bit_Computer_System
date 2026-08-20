# Mini32 RTL foundation

This directory contains the vendor-independent, synthesizable SystemVerilog implementation of Mini32. It is the hardware implementation, while the C++ simulator remains the golden architectural reference; the two share behavior, not source code or a line-by-line translation.

## Workflow

Use a Linux, WSL, or Raspberry Pi shell with Icarus Verilog and optionally Verilator installed:

```sh
cd rtl
make lint    # Verilator lint, when Verilator is available
make test    # Icarus SystemVerilog self-checking testbenches
make clean
```

Generated simulator outputs stay in `rtl/build/`. The root CMake project deliberately does not compile RTL; it continues to build the C++ golden model and software tests.

`cpu_core.sv` uses a valid/ready bus interface. When `bus_valid` is asserted, `bus_access`, `bus_addr`, and `bus_wdata` remain stable until `system_bus.sv` raises `bus_ready`. `BUS_FETCH` distinguishes instruction fetches from data reads so execute permission can be enforced. A ready response carries `bus_rdata` and `bus_fault`; CPU logic remains separate from ROM, RAM, bus, and peripherals.

`mini32_system.sv` is the synthesizable computer top level:

```text
cpu_core  <->  system_bus  <->  rom (64 KiB, read/execute)
                              <->  ram (64 KiB, read/write)
                              <->  uart_mmio (TX-only)
                              <->  timer_mmio (retired-instruction time)
                              <->  gpio_mmio (input/output/direction)
                              <->  debug_mmio (VALUE register)
                              <->  reserved STM32 window (fault today)
```

The bus permits one outstanding request. It captures a request, drives a synchronous memory or MMIO access in the next cycle, and pulses `ready` in a response cycle. This makes a normal access take at least one cycle and prevents an asserted store request from repeating writes. Misalignment is checked before address decode. ROM allows fetch/read but faults writes; RAM allows read/write but faults fetches; UART, Timer, GPIO, and Debug permit data reads/writes but fault fetches; STM32 remains unmapped.

ROM and RAM are 16,384 x 32-bit arrays, covering the full 64 KiB architectural regions without aliasing. Reads are synchronous. RAM writes are synchronous and RAM deliberately has no reset or power-up initialization; guest programs must write data before reading it. For v0.1 aligned 32-bit accesses, each array word has Mini32 little-endian external semantics.

`rom.sv` accepts `INIT_FILE` for simulation/FPGA initialization. `bin_to_mem.py` converts raw little-endian assembler output to the word-per-line `$readmemh` format (`78 56 34 12` becomes `12345678`). `make test` assembles system images including `hello_uart.asm` and `peripheral_readback.asm` into `build/generated/` before simulation. Generated files remain outside version control.

## Differential verification

`cpu_core.sv` additionally exposes a non-architectural retirement interface: `retire_pc`, `retire_instruction`, `retire_next_pc`, committed `retire_reg_write`/`retire_rd`/`retire_value`, and successful-store `retire_mem_write`/`retire_mem_addr`/`retire_mem_value`. A write to `r0`, or one that leaves a register's value unchanged, is not reported as an architectural register modification. `mini32_system.sv` also exposes fault PC, instruction, and optional data address.

`tb_differential_trace.sv` is a generic ROM-parameterized runner that emits prefixed JSONL retirement and final records. Final records include a lowercase-hex UART TX transcript and Debug VALUE. The comparator accepts either hex case from simulators and normalizes it before comparison. The repository-level runner assembles exactly one `.bin`, supplies it to `mini32_ref_trace`, converts that same binary to `.memh`, runs the RTL trace testbench, and compares the traces without comparing cycles or internal state:

```sh
python verification/differential.py --suite
```

Artifacts are retained under ignored `verification/build/` directories. The suite checks instruction stream, next PC, committed register effects, stores, halt, and faults; it deliberately does not compare cycles, bus latency, microstates, or private datapath signals.

## Current modules

| C++ reference | RTL | Role |
| --- | --- | --- |
| `Alu` | `core/alu.sv` | Combinational arithmetic and logic. |
| `RegisterFile` | `core/register_file.sv` | 32-register, two-read/one-write storage. |
| `Decoder` | `core/decoder.sv` | Field extraction and canonical encoding validation. |
| `Decoder::immediate_value` | `core/immediate_generator.sv` | Immediate extension/placement. |
| `ControlSignals` / `control_for` | `core/control_unit.sv` | Combinational opcode-to-control decode. |
| `CpuCore` | `core/cpu_core.sv` | Multi-cycle datapath/sequencer with abstract bus interface. |
| `Rom` | `memory/rom.sv` | 64 KiB synchronous program storage. |
| `Ram` | `memory/ram.sv` | 64 KiB synchronous data storage. |
| `Bus` | `bus/system_bus.sv` | One-request synchronous address decoder/interconnect. |
| — | `top/mini32_system.sv` | CPU + bus + ROM + RAM synthesizable computer. |
| `Uart` | `peripherals/uart_mmio.sv` | TX-only UART register block and event output. |
| `DebugDevice` | `peripherals/debug_mmio.sv` | Persistent Debug VALUE register. |

UART DATA writes pulse `uart_tx_valid` with the low byte and STATUS reads return `TX_READY = 1`. Debug VALUE is reset-zero, read/write at offset zero, and propagated through `mini32_system` as `debug_value`; other documented offsets read zero and ignore writes. The CPU unit test still supplies behavioral memory/bus behavior to isolate core tests; system tests exercise the real RTL hierarchy and assembled ROM images.

`timer_mmio.sv` is intentionally an instruction-time device: `retire_tick` is driven only by `cpu_core`'s successful retirement event. A control write that enables it observes that retirement as its first tick; a disable write does not tick. This gives the same final Timer state as the C++ model without comparing internal clocks. `gpio_mmio.sv` contains no tri-states; `gpio_output` and `gpio_direction` are exported for a future board wrapper.
