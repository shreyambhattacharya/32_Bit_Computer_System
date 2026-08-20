# Mini32 generic FPGA platform

`mini32_system` remains the complete architectural computer. Its UART MMIO
block emits a one-cycle `uart_tx_valid` event with `uart_tx_data[7:0]` for
each DATA write; architectural `STATUS.TX_READY` remains permanently one.

The vendor-independent physical layer is deliberately separate:

```text
mini32_system UART event -> uart_tx_fifo -> uart_tx_phy -> uart_tx pin
```

`uart_tx_fifo` defaults to 256 bytes and preserves event order while a much
slower physical UART serializes bytes. It has no architectural backpressure.
If software produces more events than its finite storage can hold, the sticky,
non-architectural `uart_overflow` signal records the loss. This makes the
v0.1 contract explicit without changing it.

`uart_tx_phy` is a vendor-neutral 8N1 transmitter (idle high, one start bit,
eight LSB-first data bits, one stop bit). `CLKS_PER_BIT` is computed at
elaboration as `(CLOCK_HZ + UART_BAUD/2) / UART_BAUD`, clamped to one. Its
achieved baud is therefore `CLOCK_HZ / CLKS_PER_BIT`; the divider's rounding
error is the difference between that value and `UART_BAUD`.

`reset_sync` asserts reset asynchronously and releases it after two `clk`
edges. `mini32_fpga_platform` exposes separate `gpio_input`, `gpio_output`,
and `gpio_direction` ports; it intentionally does not infer GPIO tri-states.
Board-specific pin mapping, reset polarity adaptation, constraints, and
clocking remain a future milestone.

Physical UART timing and FIFO occupancy are platform implementation details,
so the C++ ↔ RTL differential suite remains at the `mini32_system`
architectural boundary.
