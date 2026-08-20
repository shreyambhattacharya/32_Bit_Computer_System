# Memory Map (v0.1)

The 32-bit byte-addressed address space is decoded by one system bus. All v0.1 guest data accesses are aligned 32-bit words, even though RAM/ROM storage is byte-addressable and little-endian.

| Address range | Size | Owner | Access | Purpose |
| --- | ---: | --- | --- | --- |
| `0x0000_0000–0x0000_FFFF` | 64 KiB | ROM | read/execute | Program image, loaded by the host before reset. |
| `0x1000_0000–0x1000_FFFF` | 64 KiB | RAM | read/write | Guest variables, heap, and stack. |
| `0x2000_0000–0x2000_000F` | 16 B | UART | read/write | Console UART registers. |
| `0x2000_0100–0x2000_010F` | 16 B | Timer | reserved | Planned; currently unmapped and faults. |
| `0x2000_0200–0x2000_020F` | 16 B | GPIO | reserved | Planned; currently unmapped and faults. |
| `0x2000_0300–0x2000_030F` | 16 B | Debug | read/write | Guest-to-host diagnostic channel. |
| `0x2000_0400–0x2000_04FF` | 256 B | STM32 bridge | reserved | Planned; currently unmapped and faults. |
| all other addresses | — | — | — | bus fault |

## Peripheral registers

| Device | Offset | Register | Initial behavior |
| --- | ---: | --- | --- |
| UART | `0x00` | `DATA` | Write low byte to the host TX sink; read returns `0` until RX is implemented. |
| UART | `0x04` | `STATUS` | Bit 0 (`TX_READY`) is 1 in the host console model. |
| UART | `0x08` | `CONTROL` | Read `0`; writes are accepted with no effect. |
| UART | `0x0C` | reserved | Read `0`; writes are accepted with no effect. |
| Debug | `0x00` | `VALUE` | Reset-zero host-visible 32-bit read/write value for tests and demos. |
| Debug | `0x04` | `COMMAND` | Read `0`; writes are accepted with no effect. |
| Debug | `0x08`, `0x0C` | reserved | Read `0`; writes are accepted with no effect. |

The initial UART is TX-only: `TX_READY` is always one, there is no FIFO or backpressure, and it has no RX, interrupts, stdin connection, or asynchronous host behavior.

Timer, GPIO, and STM32 register behavior is intentionally not implemented yet. Their address ranges continue to fault until a later milestone defines each device. The STM32 bridge must eventually be reached only through normal `LW`/`SW`, never through a special CPU instruction.
