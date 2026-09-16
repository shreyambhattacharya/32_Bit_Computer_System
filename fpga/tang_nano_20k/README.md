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
generic RTL. A prior manual Gowin synthesis and place-and-route passed for the
complete design. The post-route timing report shows 68.976 MHz Fmax with zero
setup and hold total negative slack against the 27 MHz constraint. A fresh
Gowin run is still required for the current checkout. See
`reports/implementation_summary.md` for the source-controlled result summary.

### Gowin language configuration

Before RTL analysis or synthesis, configure the project to parse the `.sv`
sources as **System Verilog 2017**:

```text
Project
  -> Configuration
  -> Synthesize
  -> General
  -> Verilog Language
  -> System Verilog 2017
```

Also verify that `tang_nano_20k_top` is selected as the top module. If the
language remains plain Verilog, errors reporting unknown `logic`, `package`,
`always_comb`, or package-qualified types are parser-mode failures rather than
Mini32 RTL failures.

The Gowin version used for the validated build stores these selections in the
generated, ignored `impl/tang_nano_20k_process_config.json` metadata as
`Vlg_Std_Sysv2017` and `tang_nano_20k_top`. They are not represented by a
documented option in the checked-in `.gprj`, so every fresh project checkout
must verify the two GUI settings above. The `.sv` entries remain the
Gowin-generated/supported `type="file.verilog"` form.

Regenerate the deliberate board ROM image from the checked-in program with:

```powershell
python assembler/assembler.py programs/fpga_bringup.asm -o fpga/tang_nano_20k/rom/fpga_bringup.bin
python rtl/tools/bin_to_mem.py fpga/tang_nano_20k/rom/fpga_bringup.bin fpga/tang_nano_20k/rom/fpga_bringup.memh
python fpga/tang_nano_20k/tools/check_bringup_rom.py
```

The intermediate `.bin` and Gowin-generated `impl/` directory are ignored and
should not be committed. The board's BL616 debugger supports volatile SRAM
programming for bring-up and external flash programming for persistent boot;
neither operation has been physically performed or validated yet.

Run the board-adapter simulation from `rtl/` with:

```powershell
make tb_tang_nano_20k_top
```

On Windows, use Icarus Verilog 13 or newer for this full-platform test. If an
older `iverilog` appears earlier on `PATH`, use the Makefile's `IVERILOG` and
`VVP` overrides for the current shell. This requirement is limited to the
simulation tool; no machine-specific tool path is stored in the project.

The current host's Icarus 11.0 executable crashes during elaboration when the
board wrapper is instantiated (Windows access violation before simulation).
The generic platform and component benches still pass under that executable;
this is a simulator limitation, not physical-board evidence. The prior
Icarus 13 board-wrapper result remains the supported board-simulation baseline.

For the physical experiment, follow [BRINGUP.md](BRINGUP.md). It includes the
volatile SRAM programming sequence, serial settings, expected LED vector, and
the optional `capture_bringup.py` validator.

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
