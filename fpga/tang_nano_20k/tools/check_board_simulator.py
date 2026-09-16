#!/usr/bin/env python3
"""Check whether the selected Icarus Verilog can elaborate the board wrapper."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys


SUPPORTED_MAJOR = 13
VERSION_RE = re.compile(r"Icarus Verilog version\s+(\d+)(?:\.(\d+))?")


def get_version(command: str) -> tuple[int, str] | None:
    try:
        result = subprocess.run(
            [command, "-V"],
            capture_output=True,
            text=True,
            errors="replace",
            check=False,
        )
    except (OSError, ValueError):
        return None

    output = f"{result.stdout}\n{result.stderr}"
    match = VERSION_RE.search(output)
    if match is None:
        return None
    minor = match.group(2) or "0"
    return int(match.group(1)), f"{match.group(1)}.{minor}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--require-supported",
        action="store_true",
        help="fail instead of reporting an intentionally skipped board test",
    )
    parser.add_argument("iverilog", help="iverilog executable to inspect")
    args = parser.parse_args()

    version = get_version(args.iverilog)
    if version is None:
        message = (
            f"Icarus Verilog executable '{args.iverilog}' could not be identified; "
            "the Tang Nano 20K board-wrapper test was not run."
        )
        print(("ERROR: " if args.require_supported else "NOT TESTED: ") + message)
        return 2 if args.require_supported else 0

    major, version_text = version
    if major < SUPPORTED_MAJOR:
        message = (
            f"Icarus Verilog {version_text} is unsupported for the Tang Nano 20K "
            "board-wrapper test on this project. The known Icarus 11 Windows "
            "build crashes during elaboration; install Icarus Verilog 13+ to run "
            "this test."
        )
        print(("ERROR: " if args.require_supported else "NOT TESTED: ") + message)
        return 2 if args.require_supported else 0

    print(
        f"READY: Icarus Verilog {version_text} meets the minimum supported version "
        "for the Tang Nano 20K board-wrapper test."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
