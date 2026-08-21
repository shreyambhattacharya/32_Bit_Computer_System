# Sipeed Tang Nano 20K

## Verified board facts

This target uses the Sipeed Tang Nano 20K with Gowin FPGA
`GW2AR-LV18QN88C8/I7` (`GW2AR-18C`, QN88, C8/I7). Pin and polarity facts are
from the official [Sipeed TangNano-20K-example UART constraints](https://github.com/sipeed/TangNano-20K-example/blob/main/uart/src/top.cst),
its [UART top-level reset adaptation](https://github.com/sipeed/TangNano-20K-example/blob/main/uart/src/uart_top.v),
the official [six-LED constraints](https://github.com/sipeed/TangNano-20K-example/blob/main/led/blink_leds/src/blink_leds.cst),
the official [LED polarity example](https://github.com/sipeed/TangNano-20K-example/blob/main/led/blink_leds/src/blink_leds.v),
and the [Sipeed Tang Nano 20K LED guide](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/example/led.html).

| Signal | FPGA pin | Configuration |
| --- | ---: | --- |
| 27 MHz crystal `clk` | 4 | `LVCMOS33`, clock input |
| S1 `reset_button` | 88 | `LVCMOS33`, active-high physical button |
| debugger UART TX `uart_tx` | 69 | `LVCMOS33`, FPGA-to-PC TX |
| LED0 | 15 | active-low, pull-up |
| LED1 | 16 | active-low, pull-up |
| LED2 | 17 | active-low, pull-up |
| LED3 | 18 | active-low, pull-up |
| LED4 | 19 | active-low, pull-up |
| LED5 | 20 | active-low, pull-up |

The official UART example declares `rst_n = !rst`, establishing that the S1
input is asserted high and must be inverted before entering Mini32's generic
active-low reset input. The generic `reset_sync` remains the sole reset
synchronizer. S2 (pin 87 in Sipeed example constraints) is deliberately not
used in this milestone because it is not needed for the bring-up and no
additional GPIO semantics are being introduced.

## Board mapping

`fpga/tang_nano_20k/src/tang_nano_20k_top.sv` instantiates
`mini32_fpga_platform` with `CLOCK_HZ=27_000_000`, `UART_BAUD=115_200`, and a
256-byte event FIFO. GPIO output bits 0–3 drive LEDs only when their matching
Mini32 GPIO direction bit is configured as output. LED4 indicates `halted` and
LED5 indicates `faulted || uart_overflow`. The active-low physical LED bus is
the inverse of those logical states. All unused `gpio_input` bits are tied to
zero.

The UART path is unchanged:

```text
Mini32 software -> UART MMIO -> platform FIFO -> UART PHY -> pin 69 -> BL616 USB-UART
```

The physical UART setting is 115200 8N1. With the direct 27 MHz clock, the
rounded divider is 234 clocks/bit and the achieved baud is approximately
115384.6 (+0.16% error).

## Bring-up program and simulation

`programs/fpga_bringup.asm` configures GPIO bits 0–3 as outputs, writes a
visible pattern, writes Debug VALUE `0x54414E47`, prints `Mini32 Tang Nano 20K`
plus newline, changes the final logical GPIO output to `0xA`, and halts. The
deliberate ROM image is `fpga/tang_nano_20k/rom/fpga_bringup.memh`.

`rtl/tb/tb_tang_nano_20k_top.sv` tests the board wrapper with the real ROM
image: reset-button polarity, active-low LED behavior, direction-qualified
GPIO LEDs, UART pin output, halt LED, and fault/overflow LED behavior. It uses
no Gowin primitives. The validated Windows flow uses Icarus Verilog 13; the
older Windows Icarus 11 build crashes while elaborating this full platform
even though the same RTL passes with version 13.

## Gowin build and memory status

The checked-in `tang_nano_20k.gprj`, `.cst`, and `.sdc` are source/configuration
inputs for Gowin EDA. The project selects `GW2AR-18C`, includes the complete
64 KiB ROM and 64 KiB RAM Mini32 hierarchy, and constrains the nominal 27 MHz
clock with a 37.037 ns period. Gowin EDA is not installed in this environment,
so synthesis, place-and-route, timing, resource utilization, and bitstream
generation have not been run or claimed. The key open resource question is
that the full 128 KiB architectural memories contain 1,024 Kbit while the
device advertises 828 Kbit BSRAM; this milestone intentionally preserves the
architecture and defers any SDRAM decision until a real synthesis report.

No board has been physically programmed or validated. Future programming can
use BL616-assisted volatile SRAM programming for bring-up or external flash
programming for persistent boot. A generated `.fs` file alone would not prove
hardware success.
