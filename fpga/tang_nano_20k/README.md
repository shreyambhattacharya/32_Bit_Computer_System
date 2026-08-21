# Tang Nano 20K target

This directory contains the first board-specific Mini32 integration for the
Sipeed Tang Nano 20K (`GW2AR-LV18QN88C8/I7`, device `GW2AR-18C`). The board
wrapper is deliberately only an edge adapter; the CPU, memory map, MMIO, reset
synchronizer, UART FIFO, and UART PHY remain the existing generic RTL.

## Gowin project

Open `tang_nano_20k.gprj` in Gowin EDA, select the `GW2AR-18C` device shown in
the project, verify `tang_nano_20k_top` is selected as the top module, and run
Synthesis followed by Place & Route. The project includes
the complete Mini32 source hierarchy, board constraints, the 27 MHz SDC, and
`rom/fpga_bringup.memh`. SystemVerilog is used for both the board top and the
generic RTL. Gowin EDA is not installed in the development environment, so no
synthesis, place-and-route, timing, or bitstream result is claimed here.

Regenerate the deliberate board ROM image from the checked-in program with:

```powershell
python assembler/assembler.py programs/fpga_bringup.asm -o fpga/tang_nano_20k/rom/fpga_bringup.bin
python rtl/tools/bin_to_mem.py fpga/tang_nano_20k/rom/fpga_bringup.bin fpga/tang_nano_20k/rom/fpga_bringup.memh
```

The intermediate `.bin` is ignored and should not be committed. In Gowin, run
Synthesis, Place & Route, and timing analysis before generating a bitstream.
The board's BL616 debugger supports volatile SRAM programming for bring-up and
external flash programming for persistent boot; neither operation has been
performed from this environment.

Run the board-adapter simulation from `rtl/` with:

```powershell
make tb_tang_nano_20k_top
```

On Windows, use Icarus Verilog 13 or newer for this full-platform test. If an
older `iverilog` appears earlier on `PATH`, use the Makefile's `IVERILOG` and
`VVP` overrides for the current shell. This requirement is limited to the
simulation tool; no machine-specific tool path is stored in the project.

## Expected bring-up

With a terminal at 115200 baud, 8 data bits, no parity, and one stop bit, the
ROM program prints `Mini32 Tang Nano 20K` followed by a newline. The 27 MHz
clock gives `CLKS_PER_BIT = 234`, or approximately 115384.6 baud (+0.16%).
After the program halts, the final logical GPIO output is `0xA` with direction
`0xF`; LEDs 1 and 3 are on, LED4 (halt) is on, and LED5 is off. LED5 would turn
on for a CPU fault or physical UART FIFO overflow.

S1 is the active-high reset button and is inverted at this edge to the generic
platform's active-low `reset_n`. S2 is not mapped as GPIO until its intended
board-level use is separately verified; unused Mini32 inputs are tied low.
