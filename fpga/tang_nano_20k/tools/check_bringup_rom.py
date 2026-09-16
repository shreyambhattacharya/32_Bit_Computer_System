"""Check that the checked-in Tang Nano bring-up ROM matches its assembly source."""

from __future__ import annotations

import argparse
import hashlib
import sys
from itertools import zip_longest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "assembler"))
sys.path.insert(0, str(ROOT / "rtl" / "tools"))

from assembler import assemble_text  # noqa: E402
from bin_to_mem import convert_image  # noqa: E402


def first_difference(expected: list[str], actual: list[str]) -> str | None:
    for line_number, (expected_line, actual_line) in enumerate(
        zip_longest(expected, actual, fillvalue=None), start=1
    ):
        if expected_line != actual_line:
            return (
                f"line {line_number}: generated={expected_line!r}, "
                f"checked-in={actual_line!r}"
            )
    return None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Verify the Tang Nano 20K bring-up .memh against its .asm source."
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=ROOT / "programs" / "fpga_bringup.asm",
        help="bring-up assembly source (default: repository program)",
    )
    parser.add_argument(
        "--memh",
        type=Path,
        default=ROOT / "fpga" / "tang_nano_20k" / "rom" / "fpga_bringup.memh",
        help="checked-in word-per-line ROM image (default: board image)",
    )
    args = parser.parse_args(argv)

    try:
        generated = convert_image(
            assemble_text(args.source.read_text(encoding="utf-8"), str(args.source))
        ).splitlines()
        checked_in = args.memh.read_text(encoding="ascii").splitlines()
    except (OSError, ValueError) as error:
        print(f"ROM consistency check failed: {error}", file=sys.stderr)
        return 2

    difference = first_difference(generated, checked_in)
    if difference is not None:
        print(f"ROM consistency check failed: {difference}", file=sys.stderr)
        return 1

    digest = hashlib.sha256(args.memh.read_bytes()).hexdigest()
    print(
        f"PASS bring-up ROM matches {args.source} ({len(checked_in)} words, "
        f"SHA-256 {digest})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
