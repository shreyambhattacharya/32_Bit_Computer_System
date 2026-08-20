"""Compare C++ and RTL Mini32 execution at architectural retirement boundaries."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
TRACE_PREFIX = "MINI32_TRACE "
HEX32 = re.compile(r"[0-9A-Fa-f]{8}\Z")
HEX_BYTES = re.compile(r"(?:[0-9A-Fa-f]{2})*\Z")
RETIRE_FIELDS = {"type", "index", "pc", "instruction", "next_pc", "reg_write", "rd", "reg_value",
                 "mem_write", "mem_addr", "mem_value"}
FINAL_FIELDS = {"type", "status", "pc", "retired", "uart_tx", "debug_value", "gpio_output", "gpio_direction",
                "timer_counter", "timer_compare", "timer_control"}
FAULT_FIELDS = {"fault", "fault_pc", "fault_instruction", "fault_address_valid", "fault_address"}
SUITE = (
    "arithmetic_loop.asm", "memory_roundtrip.asm", "function_call.asm", "rtl_system_smoke.asm",
    "differential_isa.asm", "differential_unmapped_load.asm", "differential_unmapped_store.asm",
    "differential_readonly_store.asm", "differential_nonexecutable_fetch.asm",
    "differential_misaligned_fetch.asm", "differential_misaligned_load.asm",
    "differential_misaligned_store.asm", "fault_illegal.asm", "differential_malformed.asm",
    "hello_uart.asm", "debug_demo.asm", "peripheral_readback.asm", "gpio_demo.asm", "timer_demo.asm",
)


class TraceError(ValueError):
    """Trace text does not satisfy the Mini32 JSONL schema."""


class DifferentialMismatch(AssertionError):
    """Architectural traces disagree."""


def _require_hex(record: dict[str, Any], field: str) -> None:
    value = record.get(field)
    if not isinstance(value, str) or not HEX32.fullmatch(value):
        raise TraceError(f"{record.get('type', 'unknown')} field {field!r} must be 8 hexadecimal digits")
    record[field] = value.lower()


def _require_byte_stream(record: dict[str, Any], field: str) -> None:
    value = record.get(field)
    if not isinstance(value, str) or not HEX_BYTES.fullmatch(value):
        raise TraceError(f"{record.get('type', 'unknown')} field {field!r} must be an even-length hexadecimal byte stream")
    record[field] = value.lower()


def _validate_record(record: Any) -> dict[str, Any]:
    if not isinstance(record, dict):
        raise TraceError("trace record must be a JSON object")
    record_type = record.get("type")
    if record_type == "retire":
        missing = RETIRE_FIELDS - record.keys()
        if missing:
            raise TraceError(f"retire record missing fields: {', '.join(sorted(missing))}")
        if not isinstance(record["index"], int) or record["index"] < 0:
            raise TraceError("retire index must be a non-negative integer")
        if not isinstance(record["reg_write"], bool) or not isinstance(record["mem_write"], bool):
            raise TraceError("retire enable fields must be booleans")
        if not isinstance(record["rd"], int) or not 0 <= record["rd"] < 32:
            raise TraceError("retire rd must be in 0..31")
        for field in ("pc", "instruction", "next_pc", "reg_value", "mem_addr", "mem_value"):
            _require_hex(record, field)
    elif record_type == "final":
        missing = FINAL_FIELDS - record.keys()
        if missing:
            raise TraceError(f"final record missing fields: {', '.join(sorted(missing))}")
        if record["status"] not in {"halted", "faulted"}:
            raise TraceError("final status must be halted or faulted")
        if not isinstance(record["retired"], int) or record["retired"] < 0:
            raise TraceError("final retired must be a non-negative integer")
        _require_hex(record, "pc")
        _require_byte_stream(record, "uart_tx")
        for field in ("debug_value", "gpio_output", "gpio_direction", "timer_counter", "timer_compare", "timer_control"):
            _require_hex(record, field)
        if record["status"] == "faulted":
            missing = FAULT_FIELDS - record.keys()
            if missing:
                raise TraceError(f"fault final record missing fields: {', '.join(sorted(missing))}")
            if not isinstance(record["fault"], str) or not isinstance(record["fault_address_valid"], bool):
                raise TraceError("fault fields have invalid types")
            for field in ("fault_pc", "fault_instruction", "fault_address"):
                _require_hex(record, field)
    else:
        raise TraceError(f"unexpected record type: {record_type!r}")
    return record


def parse_trace(text: str, *, prefixed: bool = False) -> list[dict[str, Any]]:
    """Parse and validate one complete JSONL trace."""
    records: list[dict[str, Any]] = []
    for line_number, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            continue
        if prefixed:
            if not line.startswith(TRACE_PREFIX):
                continue
            line = line[len(TRACE_PREFIX):]
        try:
            record = json.loads(line)
        except json.JSONDecodeError as error:
            raise TraceError(f"line {line_number}: invalid JSON: {error.msg}") from error
        records.append(_validate_record(record))
    if not records:
        raise TraceError("trace contains no records")
    final_positions = [index for index, record in enumerate(records) if record["type"] == "final"]
    if final_positions != [len(records) - 1]:
        raise TraceError("trace must contain exactly one final record as its last line")
    for index, record in enumerate(records[:-1]):
        if record["type"] != "retire" or record["index"] != index:
            raise TraceError("retirement indices must be contiguous and start at zero")
    if records[-1]["retired"] != len(records) - 1:
        raise TraceError("final retired count does not equal the number of retire records")
    return records


def _first_difference(expected: dict[str, Any], actual: dict[str, Any], fields: tuple[str, ...]) -> str | None:
    for field in fields:
        if expected[field] != actual[field]:
            return f"{field} expected {expected[field]!r}, got {actual[field]!r}"
    return None


def compare_traces(cpp: list[dict[str, Any]], rtl: list[dict[str, Any]]) -> None:
    """Raise DifferentialMismatch at the first architecturally meaningful difference."""
    cpp_retire, rtl_retire = cpp[:-1], rtl[:-1]
    for index, (expected, actual) in enumerate(zip(cpp_retire, rtl_retire)):
        difference = _first_difference(expected, actual,
                                       ("type", "index", "pc", "instruction", "next_pc", "reg_write"))
        if difference is None and expected["reg_write"]:
            difference = _first_difference(expected, actual, ("rd", "reg_value"))
        if difference is None:
            difference = _first_difference(expected, actual, ("mem_write",))
        if difference is None and expected["mem_write"]:
            difference = _first_difference(expected, actual, ("mem_addr", "mem_value"))
        if difference is not None:
            raise DifferentialMismatch(
                f"Differential mismatch at retirement {index}: {difference}\nC++: {expected}\nRTL: {actual}")
    if len(cpp_retire) != len(rtl_retire):
        raise DifferentialMismatch(f"retirement trace length differs: C++={len(cpp_retire)}, RTL={len(rtl_retire)}")
    expected, actual = cpp[-1], rtl[-1]
    difference = _first_difference(expected, actual, ("type", "status", "pc", "retired", "uart_tx", "debug_value",
                                                        "gpio_output", "gpio_direction", "timer_counter",
                                                        "timer_compare", "timer_control"))
    if difference is None and expected["status"] == "faulted":
        difference = _first_difference(expected, actual,
                                       ("fault", "fault_pc", "fault_instruction", "fault_address_valid"))
        if difference is None and expected["fault_address_valid"]:
            difference = _first_difference(expected, actual, ("fault_address",))
    if difference is not None:
        raise DifferentialMismatch(f"Differential final-state mismatch: {difference}\nC++: {expected}\nRTL: {actual}")


def _run(command: list[str], *, cwd: Path, description: str) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, cwd=cwd, text=True, capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(f"{description} failed ({result.returncode})\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}")
    return result


def _tool_path(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        raise RuntimeError(f"required tool not found on PATH: {name}")
    return path


def run_case(assembly: Path, *, reference_trace: Path, work_root: Path, max_instructions: int,
             max_cycles: int, iverilog: str, vvp: str) -> None:
    case_dir = work_root / assembly.stem
    case_dir.mkdir(parents=True, exist_ok=True)
    binary, memh, cpp_jsonl, rtl_jsonl, rtl_sim = (case_dir / name for name in
                                                     ("program.bin", "program.memh", "cpp_trace.jsonl",
                                                      "rtl_trace.jsonl", "rtl_sim"))
    _run([sys.executable, str(ROOT / "assembler" / "assembler.py"), str(assembly), "-o", str(binary)],
         cwd=ROOT, description="assembler")
    _run([sys.executable, str(ROOT / "rtl" / "tools" / "bin_to_mem.py"), str(binary), str(memh)],
         cwd=ROOT, description="ROM image converter")
    cpp_result = _run([str(reference_trace), str(binary), "--max-instructions", str(max_instructions)],
                      cwd=ROOT, description="C++ reference trace")
    cpp_jsonl.write_text(cpp_result.stdout, encoding="utf-8")
    source_paths = [ROOT / path for path in (
        "rtl/include/mini32_pkg.sv", "rtl/core/alu.sv", "rtl/core/register_file.sv",
        "rtl/core/immediate_generator.sv", "rtl/core/decoder.sv", "rtl/core/control_unit.sv",
        "rtl/core/cpu_core.sv", "rtl/memory/rom.sv", "rtl/memory/ram.sv", "rtl/bus/system_bus.sv",
        "rtl/peripherals/uart_mmio.sv", "rtl/peripherals/timer_mmio.sv", "rtl/peripherals/gpio_mmio.sv",
        "rtl/peripherals/debug_mmio.sv", "rtl/top/mini32_system.sv",
        "rtl/tb/tb_differential_trace.sv")]
    parameter = f'-Ptb_differential_trace.ROM_INIT_FILE="{memh.as_posix()}"'
    _run([iverilog, "-g2012", "-s", "tb_differential_trace", parameter,
          f"-Ptb_differential_trace.MAX_CYCLES={max_cycles}", "-o", str(rtl_sim),
          *(str(path) for path in source_paths)], cwd=ROOT, description="RTL trace compilation")
    rtl_result = _run([vvp, str(rtl_sim)], cwd=ROOT, description="RTL trace simulation")
    rtl_jsonl.write_text(rtl_result.stdout, encoding="utf-8")
    compare_traces(parse_trace(cpp_result.stdout), parse_trace(rtl_result.stdout, prefixed=True))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("assembly", nargs="?", type=Path, help="one Mini32 assembly program to compare")
    parser.add_argument("--suite", action="store_true", help="run the deterministic differential corpus")
    parser.add_argument("--reference-trace", type=Path, help="path to mini32_ref_trace executable")
    parser.add_argument("--max-instructions", type=int, default=100000)
    parser.add_argument("--max-cycles", type=int, default=100000)
    args = parser.parse_args(argv)
    if args.suite == (args.assembly is not None) or args.max_instructions <= 0 or args.max_cycles <= 0:
        parser.error("provide exactly one of an assembly path or --suite and positive limits")
    reference = args.reference_trace or ROOT / "build" / ("mini32_ref_trace.exe" if sys.platform == "win32" else "mini32_ref_trace")
    if not reference.is_file():
        parser.error(f"reference trace executable not found: {reference}; build the CMake project first")
    programs = [ROOT / "programs" / name for name in SUITE] if args.suite else [args.assembly.resolve()]
    try:
        iverilog, vvp = _tool_path("iverilog"), _tool_path("vvp")
        for program in programs:
            run_case(program, reference_trace=reference.resolve(), work_root=ROOT / "verification" / "build",
                     max_instructions=args.max_instructions, max_cycles=args.max_cycles, iverilog=iverilog, vvp=vvp)
            print(f"PASS {program.name}")
    except (OSError, RuntimeError, TraceError, DifferentialMismatch) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
