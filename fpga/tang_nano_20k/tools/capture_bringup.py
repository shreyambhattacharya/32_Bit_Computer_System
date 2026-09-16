"""Capture and validate the Mini32 Tang Nano 20K UART bring-up message."""

from __future__ import annotations

import argparse
import sys
import time

EXPECTED = b"Mini32 Tang Nano 20K\n"
BAUD_RATE = 115200


def display_bytes(data: bytes) -> str:
    return repr(data.decode("ascii", errors="backslashreplace"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Capture the FPGA UART output and validate the Mini32 bring-up message."
    )
    parser.add_argument("port", help="Windows serial port, for example COM7")
    parser.add_argument(
        "--timeout",
        type=float,
        default=10.0,
        help="total seconds to wait for the complete message (default: 10)",
    )
    parser.add_argument(
        "--no-prompt",
        action="store_true",
        help="start reading immediately; use only when reset is controlled separately",
    )
    args = parser.parse_args(argv)
    if args.timeout <= 0:
        parser.error("--timeout must be positive")

    try:
        import serial
    except ModuleNotFoundError:
        print(
            "pyserial is required. Install it in your user Python environment with "
            "'python -m pip install --user pyserial'.",
            file=sys.stderr,
        )
        return 2

    try:
        connection = serial.Serial(
            port=args.port,
            baudrate=BAUD_RATE,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.1,
            xonxoff=False,
            rtscts=False,
            dsrdtr=False,
        )
    except (serial.SerialException, OSError) as error:
        print(
            f"Unable to open {args.port}: {error}. Close any terminal or programmer "
            "using this COM port and verify the port name in Device Manager.",
            file=sys.stderr,
        )
        return 2

    try:
        with connection:
            # Discard bytes from an earlier run. The reset prompt below ensures
            # that retained bytes belong to the fresh guest execution.
            connection.reset_input_buffer()
            if not args.no_prompt:
                try:
                    input(
                        f"{args.port} is open at {BAUD_RATE} 8N1. Press and hold S1, "
                        "release it, then press Enter here to validate the fresh run: "
                    )
                except (EOFError, KeyboardInterrupt):
                    print("Capture cancelled.", file=sys.stderr)
                    return 2

            captured = bytearray()
            deadline = time.monotonic() + args.timeout
            while len(captured) < len(EXPECTED) and time.monotonic() < deadline:
                captured.extend(connection.read(len(EXPECTED) - len(captured)))
    except (serial.SerialException, OSError) as error:
        print(f"Serial capture failed on {args.port}: {error}", file=sys.stderr)
        return 2

    if len(captured) < len(EXPECTED):
        print(
            f"TIMEOUT: received {len(captured)}/{len(EXPECTED)} bytes: "
            f"{display_bytes(bytes(captured))}",
            file=sys.stderr,
        )
        return 1
    if bytes(captured) != EXPECTED:
        print(
            f"MISMATCH: received {display_bytes(bytes(captured))}; "
            f"expected {display_bytes(EXPECTED)}",
            file=sys.stderr,
        )
        return 1

    print(f"PASS: received {display_bytes(bytes(captured))} from {args.port}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
