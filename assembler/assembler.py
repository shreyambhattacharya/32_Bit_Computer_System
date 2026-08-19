"""Two-pass assembler for the Mini32 v0.1 ISA."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from mini32_isa import (BRANCH_INSTRUCTIONS, JUMP_INSTRUCTIONS, R_INSTRUCTIONS,
                        REGISTER_ALIASES, SIGNED_I_INSTRUCTIONS, UNSIGNED_I_INSTRUCTIONS,
                        Opcode)

LABEL_PATTERN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:")
MEMORY_PATTERN = re.compile(r"^\s*([^()\s]+)\s*\(\s*([^()\s]+)\s*\)\s*$")


class AssemblyError(Exception):
    def __init__(self, filename: str, line: int, message: str):
        super().__init__(f"{filename}:{line}: {message}")


@dataclass(frozen=True)
class Statement:
    line: int
    text: str
    address: int


def parse_register(token: str, statement: Statement, filename: str) -> int:
    lowered = token.strip().lower()
    if lowered in REGISTER_ALIASES:
        return REGISTER_ALIASES[lowered]
    match = re.fullmatch(r"r(\d+)", lowered)
    if not match:
        raise AssemblyError(filename, statement.line, f"invalid register '{token}'")
    value = int(match.group(1), 10)
    if not 0 <= value <= 31:
        raise AssemblyError(filename, statement.line, f"register {token} is outside r0-r31")
    return value


def parse_number(token: str, statement: Statement, filename: str) -> int:
    try:
        return int(token, 0)
    except ValueError as error:
        raise AssemblyError(filename, statement.line, f"invalid numeric literal '{token}'") from error


def checked_range(value: int, minimum: int, maximum: int, description: str,
                  statement: Statement, filename: str) -> int:
    if not minimum <= value <= maximum:
        raise AssemblyError(filename, statement.line,
                            f"{description} {value} is outside {minimum}..{maximum}")
    return value


def split_operands(operand_text: str, count: int, statement: Statement, filename: str) -> list[str]:
    operands = [part.strip() for part in operand_text.split(",")] if operand_text.strip() else []
    if len(operands) != count or any(not operand for operand in operands):
        raise AssemblyError(filename, statement.line, f"expected {count} operand(s)")
    return operands


def parse_source(source: str, filename: str) -> tuple[dict[str, int], list[Statement]]:
    labels: dict[str, int] = {}
    statements: list[Statement] = []
    address = 0
    for line_number, raw_line in enumerate(source.splitlines(), start=1):
        remaining = raw_line.split("#", 1)[0].strip()
        while remaining:
            match = LABEL_PATTERN.match(remaining)
            if not match:
                break
            label = match.group(1)
            if label in labels:
                raise AssemblyError(filename, line_number, f"duplicate label '{label}'")
            labels[label] = address
            remaining = remaining[match.end():].strip()
        if not remaining:
            continue
        if ":" in remaining:
            raise AssemblyError(filename, line_number, "invalid label syntax")
        statements.append(Statement(line_number, remaining, address))
        address += 4
    return labels, statements


def resolve_displacement(token: str, bits: int, statement: Statement, filename: str,
                         labels: dict[str, int]) -> int:
    try:
        value = int(token, 0)
    except ValueError:
        if token not in labels:
            raise AssemblyError(filename, statement.line, f"undefined label '{token}'")
        byte_delta = labels[token] - (statement.address + 4)
        if byte_delta % 4 != 0:
            raise AssemblyError(filename, statement.line, f"label '{token}' is not instruction aligned")
        value = byte_delta // 4
    return checked_range(value, -(1 << (bits - 1)), (1 << (bits - 1)) - 1,
                         f"signed {bits}-bit displacement", statement, filename)


def parse_memory_operand(token: str, statement: Statement, filename: str) -> tuple[int, int]:
    match = MEMORY_PATTERN.fullmatch(token)
    if not match:
        raise AssemblyError(filename, statement.line, f"invalid memory operand '{token}'")
    offset = checked_range(parse_number(match.group(1), statement, filename), -32768, 32767,
                           "signed 16-bit offset", statement, filename)
    return offset, parse_register(match.group(2), statement, filename)


def encode_statement(statement: Statement, filename: str, labels: dict[str, int]) -> int:
    pieces = statement.text.split(None, 1)
    mnemonic = pieces[0].upper()
    operand_text = pieces[1] if len(pieces) == 2 else ""
    if mnemonic == "RET":
        mnemonic, operand_text = "JR", "r31"
    if mnemonic == ".WORD":
        value = checked_range(parse_number(operand_text.strip(), statement, filename), 0, 0xFFFFFFFF,
                              ".word value", statement, filename)
        return value
    if mnemonic == "NOP" or mnemonic == "HALT":
        split_operands(operand_text, 0, statement, filename)
        return int(Opcode[mnemonic]) << 26
    if mnemonic not in Opcode.__members__:
        raise AssemblyError(filename, statement.line, f"unknown mnemonic '{pieces[0]}'")
    opcode = int(Opcode[mnemonic]) << 26
    if mnemonic in R_INSTRUCTIONS:
        rd_token, rs1_token, rs2_token = split_operands(operand_text, 3, statement, filename)
        return opcode | (parse_register(rd_token, statement, filename) << 21) | \
            (parse_register(rs1_token, statement, filename) << 16) | \
            (parse_register(rs2_token, statement, filename) << 11)
    if mnemonic == "LUI":
        rd_token, immediate_token = split_operands(operand_text, 2, statement, filename)
        immediate = checked_range(parse_number(immediate_token, statement, filename), 0, 65535,
                                  "unsigned 16-bit immediate", statement, filename)
        return opcode | (parse_register(rd_token, statement, filename) << 21) | immediate
    if mnemonic in {"ADDI", "ANDI", "ORI", "XORI"}:
        rd_token, rs1_token, immediate_token = split_operands(operand_text, 3, statement, filename)
        immediate = parse_number(immediate_token, statement, filename)
        if mnemonic in SIGNED_I_INSTRUCTIONS:
            immediate = checked_range(immediate, -32768, 32767, "signed 16-bit immediate", statement, filename)
        else:
            immediate = checked_range(immediate, 0, 65535, "unsigned 16-bit immediate", statement, filename)
        return opcode | (parse_register(rd_token, statement, filename) << 21) | \
            (parse_register(rs1_token, statement, filename) << 16) | (immediate & 0xFFFF)
    if mnemonic == "LW":
        rd_token, memory_token = split_operands(operand_text, 2, statement, filename)
        offset, base = parse_memory_operand(memory_token, statement, filename)
        return opcode | (parse_register(rd_token, statement, filename) << 21) | (base << 16) | (offset & 0xFFFF)
    if mnemonic == "SW":
        rs2_token, memory_token = split_operands(operand_text, 2, statement, filename)
        offset, base = parse_memory_operand(memory_token, statement, filename)
        return opcode | (parse_register(rs2_token, statement, filename) << 21) | (base << 16) | (offset & 0xFFFF)
    if mnemonic in BRANCH_INSTRUCTIONS:
        rs1_token, rs2_token, target_token = split_operands(operand_text, 3, statement, filename)
        displacement = resolve_displacement(target_token, 16, statement, filename, labels)
        return opcode | (parse_register(rs1_token, statement, filename) << 21) | \
            (parse_register(rs2_token, statement, filename) << 16) | (displacement & 0xFFFF)
    if mnemonic in JUMP_INSTRUCTIONS:
        target_token = split_operands(operand_text, 1, statement, filename)[0]
        displacement = resolve_displacement(target_token, 26, statement, filename, labels)
        return opcode | (displacement & 0x03FFFFFF)
    if mnemonic == "JR":
        register_token = split_operands(operand_text, 1, statement, filename)[0]
        return opcode | (parse_register(register_token, statement, filename) << 21)
    raise AssemblyError(filename, statement.line, f"unsupported mnemonic '{mnemonic}'")


def assemble_text(source: str, filename: str = "<string>") -> bytes:
    labels, statements = parse_source(source, filename)
    words = [encode_statement(statement, filename, labels) for statement in statements]
    return b"".join(word.to_bytes(4, byteorder="little", signed=False) for word in words)


def assemble_file(input_path: Path, output_path: Path) -> None:
    try:
        source = input_path.read_text(encoding="utf-8")
    except OSError as error:
        raise AssemblyError(str(input_path), 0, str(error)) from error
    output_path.write_bytes(assemble_text(source, str(input_path)))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Assemble Mini32 v0.1 source into a raw little-endian ROM image.")
    parser.add_argument("input", type=Path, help="Mini32 assembly source file")
    parser.add_argument("-o", "--output", type=Path, required=True, help="output binary image path")
    args = parser.parse_args(argv)
    try:
        assemble_file(args.input, args.output)
    except AssemblyError as error:
        print(error, file=sys.stderr)
        return 1
    except OSError as error:
        print(f"{args.output}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
