# Tang Nano 20K implementation summary

## Target

| Item | Value |
| --- | --- |
| Board | Sipeed Tang Nano 20K |
| Device | `GW2AR-LV18QN88C8/I7` |
| Clock | 27 MHz (`clk_27M`, 37.037 ns) |

## Verified Gowin results

Resource figures are from the synthesis report; Fmax and slack are from the
post-place-and-route timing report.

| Measurement | Result |
| --- | ---: |
| Logic | 3910 / 20736 (19%) |
| LUT | 3652 |
| ALU | 258 |
| Registers | 1628 / 15750 (11%) |
| BSRAM | 34 / 46 (74%) |
| Post-route Fmax | 68.976 MHz |
| Post-route logic level | 6 |
| Setup TNS | 0.000 |
| Setup failing endpoints | 0 |
| Hold TNS | 0.000 |
| Hold failing endpoints | 0 |
| Timing result at 27 MHz | PASS |

Synthesis, resource fit, place-and-route, and timing closure passed. The full
64 KiB ROM and 64 KiB RAM architecture fits without SDRAM.

## Physical validation

**NOT YET PERFORMED.** The FPGA board has not yet been programmed or tested.
