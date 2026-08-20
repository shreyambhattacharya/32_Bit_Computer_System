"""Convert a raw little-endian Mini32 image to one word-per-line .memh."""

from __future__ import annotations

import argparse
from pathlib import Path

ROM_SIZE_BYTES = 64 * 1024


def convert_image(raw_image: bytes) -> str:
    """Return uppercase 32-bit hexadecimal words for a raw little-endian image."""
    if len(raw_image) % 4:
        raise ValueError("input size must be divisible by 4 bytes")
    if len(raw_image) > ROM_SIZE_BYTES:
        raise ValueError("input image exceeds the 64 KiB Mini32 ROM capacity")
    return "".join(f"{int.from_bytes(raw_image[offset:offset + 4], 'little'):08X}\n"
                   for offset in range(0, len(raw_image), 4))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Convert a Mini32 raw little-endian .bin image to .memh.")
    parser.add_argument("input", type=Path, help="raw Mini32 .bin image")
    parser.add_argument("output", type=Path, help="word-per-line hexadecimal .memh output")
    args = parser.parse_args(argv)
    try:
        args.output.write_text(convert_image(args.input.read_bytes()), encoding="ascii")
    except (OSError, ValueError) as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
