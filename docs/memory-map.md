# Memory Map (v0.1)

The 32-bit byte-addressed address space is decoded by one system bus. All v0.1 guest data accesses are aligned 32-bit words, even though RAM/ROM storage is byte-addressable and little-endian.

| Address range | Size | Owner | Access | Purpose |
| --- | ---: | --- | --- | --- |
| `0x0000_0000–0x0000_FFFF` | 64 KiB | ROM | read/execute | Program image, loaded by the host before reset. |
| `0x1000_0000–0x1000_FFFF` | 64 KiB | RAM | read/write | Guest variables, heap, and stack. |
| `0x2000_0000–0x2000_000F` | 16 B | UART | read/write | Console UART registers. |
| `0x2000_0100–0x2000_010F` | 16 B | Timer | read/write | Deterministic cycle counter/comparator. |
| `0x2000_0200–0x2000_020F` | 16 B | GPIO | read/write | Simulated input/output pins. |
| `0x2000_0300–0x2000_030F` | 16 B | Debug | read/write | Guest-to-host diagnostic channel. |
| `0x2000_0400–0x2000_04FF` | 256 B | STM32 bridge | read/write | Reserved physical peripheral protocol region. |
| all other addresses | — | — | — | bus fault |

## Peripheral registers

| Device | Offset | Register | Initial behavior |
| --- | ---: | --- | --- |
| UART | `0x00` | `DATA` | Write low byte to host terminal; read returns last received byte when implemented. |
| UART | `0x04` | `STATUS` | Bit 0 (`TX_READY`) is 1 in the host console model. |
| UART | `0x08` | `CONTROL` | Reserved for enable/interrupt configuration. |
| Timer | `0x00` | `COUNTER` | Increments deterministically with CPU ticks. |
| Timer | `0x04` | `COMPARE` | Comparison value for later event/interrupt support. |
| Timer | `0x08` | `CONTROL` | Bit 0 enables counting. |
| Timer | `0x0C` | `STATUS` | Later comparison-pending bit. |
| GPIO | `0x00` | `INPUT` | Host/STM32 supplied input pins. |
| GPIO | `0x04` | `OUTPUT` | Guest-driven output pins. |
| GPIO | `0x08` | `DIRECTION` | 1 means output, 0 means input. |
| Debug | `0x00` | `VALUE` | Host-visible 32-bit value for tests and demos. |
| Debug | `0x04` | `COMMAND` | Reserved for explicit simulator services. |

The STM32 window stays reserved until its packet protocol is specified. It must be reached only through normal `LW`/`SW`, never through a special CPU instruction.
