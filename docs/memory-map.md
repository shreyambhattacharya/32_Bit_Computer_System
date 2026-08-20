# Memory Map (v0.1)

The 32-bit byte-addressed address space is decoded by one system bus. All v0.1 guest data accesses are aligned 32-bit words, even though RAM/ROM storage is byte-addressable and little-endian.

| Address range | Size | Owner | Access | Purpose |
| --- | ---: | --- | --- | --- |
| `0x0000_0000–0x0000_FFFF` | 64 KiB | ROM | read/execute | Program image, loaded by the host before reset. |
| `0x1000_0000–0x1000_FFFF` | 64 KiB | RAM | read/write | Guest variables, heap, and stack. |
| `0x2000_0000–0x2000_000F` | 16 B | UART | read/write | Console UART registers. |
| `0x2000_0100–0x2000_010F` | 16 B | Timer | read/write | Deterministic retired-instruction counter. |
| `0x2000_0200–0x2000_020F` | 16 B | GPIO | read/write | INPUT pins and OUTPUT/DIRECTION latches. |
| `0x2000_0300–0x2000_030F` | 16 B | Debug | read/write | Guest-to-host diagnostic channel. |
| `0x2000_0400–0x2000_04FF` | 256 B | STM32 bridge | reserved | Planned; currently unmapped and faults. |
| all other addresses | — | — | — | bus fault |

## Peripheral registers

| Device | Offset | Register | Initial behavior |
| --- | ---: | --- | --- |
| UART | `0x00` | `DATA` | Write low byte to a one-cycle RTL `tx_valid` event; read returns `0` until RX is implemented. |
| UART | `0x04` | `STATUS` | Bit 0 (`TX_READY`) is always `1`. |
| UART | `0x08` | `CONTROL` | Read `0`; writes are accepted with no effect. |
| UART | `0x0C` | reserved | Read `0`; writes are accepted with no effect. |
| Debug | `0x00` | `VALUE` | Reset-zero host-visible 32-bit read/write value for tests and demos. |
| Debug | `0x04` | `COMMAND` | Read `0`; writes are accepted with no effect. |
| Debug | `0x08`, `0x0C` | reserved | Read `0`; writes are accepted with no effect. |
| Timer | `0x00` | `COUNTER` | Read/write 32-bit instruction-time counter. |
| Timer | `0x04` | `COMPARE` | Read/write match value. |
| Timer | `0x08` | `CONTROL` | Bit 0 enables the Timer; all other bits read `0`. |
| Timer | `0x0C` | `STATUS` | Bit 0 is `ENABLE && COUNTER == COMPARE`; writes have no effect. |
| GPIO | `0x00` | `INPUT` | Read external input; writes have no effect. |
| GPIO | `0x04` | `OUTPUT` | Read/write output latch. |
| GPIO | `0x08` | `DIRECTION` | Read/write direction latch (`0` input, `1` output). |
| GPIO | `0x0C` | reserved | Read `0`; writes have no effect. |

The initial UART is TX-only: `TX_READY` is always one, each DATA write yields exactly one `tx_valid` event, and there is no FIFO, backpressure, RX, interrupts, stdin connection, or asynchronous host behavior. The synthesizable Debug VALUE output is propagated from the RTL top level for test and board-integration observation.

The Timer increments once after every successfully retired instruction when enabled, including the instruction that enables it and HALT; faulting instructions never tick it. It is not a real-time clock or raw FPGA-cycle counter. GPIO has no internal tri-states; a future board wrapper maps its output and direction signals to pins. The STM32 bridge remains unimplemented and its data accesses fault.
