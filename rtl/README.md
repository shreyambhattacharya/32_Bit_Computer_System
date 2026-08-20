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

## Current modules

| C++ reference | RTL | Role |
| --- | --- | --- |
| `Alu` | `core/alu.sv` | Combinational arithmetic and logic. |
| `RegisterFile` | `core/register_file.sv` | 32-register, two-read/one-write storage. |
| `Decoder` | `core/decoder.sv` | Field extraction and canonical encoding validation. |
| `Decoder::immediate_value` | `core/immediate_generator.sv` | Immediate extension/placement. |
| `ControlSignals` / `control_for` | `core/control_unit.sv` | Combinational opcode-to-control decode. |
| `CpuCore` | future `core/cpu_core.sv` | Multi-cycle datapath/sequencer. |
| `Rom` | future `memory/rom.sv` | Program storage. |
| `Ram` | future `memory/ram.sv` | Data storage. |
| `Bus` | future `bus/bus.sv` | Address decoding/interconnect. |
| `Uart` | future `peripherals/uart.sv` | UART register block. |
| `DebugDevice` | future `peripherals/debug_device.sv` | Debug register block. |

The future `memory/`, `bus/`, `peripherals/`, and `top/` hierarchy is intentionally not implemented during this foundation milestone.
