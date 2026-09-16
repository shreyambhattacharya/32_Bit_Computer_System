# Mini32 Tang Nano 20K bring-up

This procedure validates the real Mini32 CPU image on a Sipeed Tang Nano 20K.
It is intentionally a volatile SRAM test: power cycling the board removes the
image, and this procedure does not erase or program the board's external flash.

The board facts used here are cross-checked against the [official Tang Nano 20K
page](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html), the
[official UART example](https://github.com/sipeed/TangNano-20K-example/tree/main/uart),
the [official LED example](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/example/led.html),
and the [Gowin Programmer guide](https://cdn.gowinsemi.com.cn/SUG502E.pdf).

## 1. Required hardware

1. Sipeed Tang Nano 20K board with its onboard BL616 debugger.
2. One USB-C data cable connected to the board's debugger USB-C connector and
   the Windows computer. A charge-only cable is not sufficient.
3. No Raspberry Pi, STM32 Nucleo, jumper wires, external UART adapter, or
   external power supply is required for this test. The onboard debugger
   provides both FPGA JTAG programming and USB-to-UART.

## 2. Install or verify software

1. Install Gowin FPGA Designer (Gowin EDA) for Windows, including the Gowin
   Programmer and USB/debugger driver components. Sipeed's [IDE installation
   guide](https://wiki.sipeed.com/hardware/en/tang/common-doc/get_started/install-the-ide.html)
   describes the Windows installation and driver steps. The Education Edition
   supports the `GW2AR-LV18QN88C8/I7` device; the Standard Edition requires its
   normal Gowin license.
2. Install a serial terminal such as Windows Terminal with a serial utility,
   Tera Term, or PuTTY. Only one application may own the debugger COM port at a
   time.
3. Optional: install `pyserial` only if using the validator below. Do not
   install it globally:

   ```powershell
   python -m pip install --user pyserial
   ```

## 3. Build and locate the bitstream

1. From the repository root, regenerate and check the deliberate bring-up ROM:

   ```powershell
   python assembler/assembler.py programs/fpga_bringup.asm -o fpga/tang_nano_20k/rom/fpga_bringup.bin
   python rtl/tools/bin_to_mem.py fpga/tang_nano_20k/rom/fpga_bringup.bin fpga/tang_nano_20k/rom/fpga_bringup.memh
   python fpga/tang_nano_20k/tools/check_bringup_rom.py
   ```

2. Open `fpga/tang_nano_20k/tang_nano_20k.gprj` in Gowin FPGA Designer.
3. Confirm the device is `GW2AR-LV18QN88C8/I7` / `GW2AR-18C`, the top module is
   `tang_nano_20k_top`, and the file list includes all RTL sources,
   `rom/fpga_bringup.memh`, `src/tang_nano_20k.cst`, and
   `src/tang_nano_20k.sdc`.
4. Set **Project → Configuration → Synthesize → General → Verilog Language**
   to **System Verilog 2017**. Run RTL Analysis, Synthesis, Place & Route, and
   timing analysis. The generated programming file is normally under the
   project `impl\pnr\` directory; use the actual `.fs` filename shown by Gowin,
   not a guessed name. Do not add generated `impl\` output to git.

If Gowin reports a missing top module, right-click `tang_nano_20k_top` in the
Hierarchy view and choose **Set as Top Module**. The checked-in `.gprj` lists the
source files but does not reliably preserve these GUI-generated settings across
Gowin versions.

## 4. Connect and identify the board

1. Close the serial terminal before programming. Sipeed's official example
   states that the FPGA cannot be programmed while the serial port is open.
2. Connect the USB-C data cable directly to the computer, avoiding a hub for
   the first test.
3. Open **Device Manager → Ports (COM & LPT)** and note the newly appearing
   USB Serial/BL616 COM port. If several COM ports exist, unplug and reconnect
   the board to identify the one that changes. Do not guess from `COM3`, `COM4`,
   or another number.
4. Start Gowin Programmer, choose **Scan Device**, and confirm that a Gowin
   device is detected. The expected FPGA identity is `GW2AR-18C` with package
   `QN88` and speed `C8/I7`.

## 5. Program volatile SRAM (do not program flash)

1. Keep the serial terminal closed.
2. In Gowin Programmer, select the detected device and open the operation
   configuration.
3. Select **SRAM Mode** and **SRAM Program**. Select the actual `.fs` generated
   by this project from `impl\pnr\`.
4. Before clicking the program button, verify the planned operation reads:
   `GW2AR-18C`, the actual `.fs` path, **SRAM Mode / SRAM Program**, and no
   `External Flash`, `exFlash`, `Erase`, or `Program Flash` operation.
5. Click the program/download control and save the Gowin log. This is the only
   programming operation in this procedure. Do not choose external flash for
   initial bring-up, and do not update BL616 debugger firmware.

## 6. Open the serial terminal

1. Close Gowin Programmer or otherwise release the debugger connection after
   programming.
2. Open the COM port identified in Device Manager with:

   ```text
   Baud rate: 115200
   Data bits: 8
   Parity: None
   Stop bits: 1
   Flow control: None
   ```

3. The program may already have finished before the terminal opens. Therefore
   open the terminal first, then press and hold **S1**, release it, and observe
   the new output. **S1 is the reset button; S2 is intentionally unused.**

The optional capture utility opens the COM port before asking for this reset:

```powershell
python fpga/tang_nano_20k/tools/capture_bringup.py COM7 --timeout 10
```

Replace `COM7` with the port actually identified on this computer. When the
utility prompts, press and hold S1, release it, then press Enter. It reports
`PASS` only after receiving the expected bytes from the open serial port.

## 7. Expected results

After S1 is released, the physical UART must transmit exactly:

```text
Mini32 Tang Nano 20K
```

followed by one newline byte (`0x0A`). The expected architectural GPIO state is
`OUTPUT = 0x0000000A`, `DIRECTION = 0x0000000F`. LEDs are active-low:

| LED | Expected state | Meaning |
| --- | --- | --- |
| LED0 | OFF | GPIO bit 0 = 0 |
| LED1 | ON | GPIO bit 1 = 1 |
| LED2 | OFF | GPIO bit 2 = 0 |
| LED3 | ON | GPIO bit 3 = 1 |
| LED4 | ON | CPU halted |
| LED5 | OFF | No CPU fault and no UART FIFO overflow |

The physical vector, written LED5 through LED0, is `6'b100101`. Pressing and
releasing S1 must cause the same UART message and final LED state again.

## 8. Troubleshooting

1. **No device in Gowin Programmer:** close the terminal, disconnect the board,
   reconnect it directly to the PC with another known-good data cable, and
   rescan. In Device Manager, check whether a USB Serial/BL616 device appears;
   if it has a warning icon, reinstall the driver components from Gowin/Sipeed.
2. **COM port exists but capture says busy:** close PuTTY/Tera Term/Windows
   serial tools and Gowin Programmer, then rerun the capture. Only one program
   can own the onboard debugger at a time.
3. **Programmer reports wrong device or ID mismatch:** stop before programming,
   verify the project and Programmer device are both `GW2AR-18C`, `QN88`,
   `C8/I7`, and rescan. Do not force a different device.
4. **Programmer succeeds but LEDs remain all off:** hold S1 and release it once;
   verify the selected `.fs` came from the fresh `impl\pnr\` build and that
   RTL Analysis used SystemVerilog 2017. If LED4 never turns on, capture the
   Gowin log and note whether LED5 is on.
5. **LED5 is on:** treat this as a real fault/overflow indication. Do not call
   the run successful. Re-run the software ROM check, confirm the `.memh` is in
   the Gowin file list, inspect the final `fault_code`/UART overflow signals in
   simulation, and report the observed LED vector.
6. **UART is silent or garbled:** verify the terminal is on the debugger COM
   port at 115200 8N1 with flow control disabled. Close the terminal, press and
   release S1, reopen it, and then use the capture utility with the terminal
   closed. A correct serial capture proves the FPGA TX path; a correct LED4
   with no UART output points to COM-port ownership or the debugger UART path.
7. **UART output is only a prefix or times out:** make sure the capture utility
   was opened before pressing S1, increase `--timeout`, and verify LED5 is off.
   The 21-byte message takes about 1.8 ms at 115200 8N1, so resetting after the
   reader is open is important.
8. **S1 does not restart the message:** hold S1 for at least one second, release
   it, and confirm the button is not being confused with S2. If LED4 clears on
   reset but never returns, record the UART capture and LED5 state; this
   distinguishes reset/clock operation from guest execution.

## Verification status

This guide prepares the physical experiment. A software or RTL simulation is
not physical evidence. Until a Gowin programming log, serial capture, observed
LED vector, and S1 repeat are recorded from the real board, mark each physical
item **NOT TESTED**, not PASS.
