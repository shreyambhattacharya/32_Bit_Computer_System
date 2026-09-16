# Tang Nano 20K implementation summary

## Target

| Item | Value |
| --- | --- |
| Board | Sipeed Tang Nano 20K |
| Device | `GW2AR-LV18QN88C8/I7` |
| Clock | 27 MHz (`clk_27M`, 37.037 ns) |

## Prior recorded Gowin results

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

Synthesis, resource fit, place-and-route, and timing closure passed in the prior
recorded run. The full 64 KiB ROM and 64 KiB RAM architecture fits without
SDRAM. These figures are not a fresh implementation result for the current
checkout.

## Physical validation

**NOT YET PERFORMED.** The FPGA board has not yet been programmed or tested.

## 2026-09-16 host bring-up audit

| Boundary | Result | Evidence |
| --- | --- | --- |
| C++ reference build and tests | PASS | Visual Studio-bundled CMake/CTest: 16/16 tests |
| Python tests | PASS | `tests/python` and `verification/tests` |
| C++ ↔ RTL differential suite | PASS | 20 corpus programs |
| ROM regenerated from assembly | PASS | Checked-in `.memh` matches; SHA-256 `5C99BD38C57F333C4C6CB0E74CC54FC2B921CF54E35B097CE47FE40E2D952E51` |
| RTL component/platform benches | PASS | Icarus 11.0 benches through generic platform |
| Tang board-wrapper simulation | NOT TESTED | Icarus 11.0 crashes during wrapper elaboration; supported Icarus 13 is not installed |
| Fresh Gowin implementation | NOT TESTED | Gowin tools are not installed on the audit host |
| FPGA programming / UART / GPIO / reset | NOT TESTED | No physical programming operation was authorized or performed |

The prior resource and timing numbers above are retained as historical
measurements from the recorded Gowin run; this audit did not generate a new
bitstream, resource report, timing report, path, or checksum.
