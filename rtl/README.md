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

`cpu_core.sv` uses an abstract valid/ready bus interface. When `bus_valid` is asserted, `bus_access`, `bus_addr`, and `bus_wdata` remain stable until the future bus raises `bus_ready`. `BUS_FETCH` distinguishes instruction fetches from data reads so execute permission can be enforced. A ready response carries `bus_rdata` and `bus_fault`; the CPU has no ROM, RAM, bus, or peripheral implementation internally.

## Current modules

| C++ reference | RTL | Role |
| --- | --- | --- |
| `Alu` | `core/alu.sv` | Combinational arithmetic and logic. |
| `RegisterFile` | `core/register_file.sv` | 32-register, two-read/one-write storage. |
| `Decoder` | `core/decoder.sv` | Field extraction and canonical encoding validation. |
| `Decoder::immediate_value` | `core/immediate_generator.sv` | Immediate extension/placement. |
| `ControlSignals` / `control_for` | `core/control_unit.sv` | Combinational opcode-to-control decode. |
| `CpuCore` | `core/cpu_core.sv` | Multi-cycle datapath/sequencer with abstract bus interface. |
| `Rom` | future `memory/rom.sv` | Program storage. |
| `Ram` | future `memory/ram.sv` | Data storage. |
| `Bus` | future `bus/bus.sv` | Address decoding/interconnect. |
| `Uart` | future `peripherals/uart.sv` | UART register block. |
| `DebugDevice` | future `peripherals/debug_device.sv` | Debug register block. |

The future `memory/`, `bus/`, `peripherals/`, and `top/` hierarchy remains intentionally unimplemented. The CPU testbench supplies behavioral memory and bus behavior only for verification.
