"""Disassembler for raw little-endian Mini32 v0.1 ROM images."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from mini32_isa import Opcode, R_INSTRUCTIONS, sign_extend


def register(index: int) -> str:
    return f"r{index}"


def invalid(word: int) -> str:
    return f".word 0x{word:08X}"


def disassemble_word(word: int) -> str:
    raw_opcode = word >> 26
    try:
        opcode = Opcode(raw_opcode)
    except ValueError:
        return invalid(word)
    mnemonic = opcode.name
    rd = (word >> 21) & 0x1F
    rs1 = (word >> 16) & 0x1F
    rs2 = (word >> 11) & 0x1F
    imm16 = word & 0xFFFF
    if mnemonic == "NOP":
        return "NOP" if word == 0 else invalid(word)
    if mnemonic == "HALT":
        return "HALT" if word == (int(opcode) << 26) else invalid(word)
    if mnemonic in R_INSTRUCTIONS:
        return invalid(word) if (word & 0x7FF) else f"{mnemonic} {register(rd)}, {register(rs1)}, {register(rs2)}"
    if mnemonic == "JR":
        return invalid(word) if (word & 0x1FFFFF) else f"JR {register((word >> 21) & 0x1F)}"
    if mnemonic == "LUI":
        return invalid(word) if rs1 else f"LUI {register(rd)}, 0x{imm16:04X}"
    if mnemonic in {"ADDI", "LW"}:
        signed = sign_extend(imm16, 16)
        if mnemonic == "ADDI":
            return f"ADDI {register(rd)}, {register(rs1)}, {signed}"
        return f"LW {register(rd)}, {signed}({register(rs1)})"
    if mnemonic in {"ANDI", "ORI", "XORI"}:
        return f"{mnemonic} {register(rd)}, {register(rs1)}, 0x{imm16:04X}"
    if mnemonic == "SW":
        return f"SW {register(rd)}, {sign_extend(imm16, 16)}({register(rs1)})"
    if mnemonic in {"BEQ", "BNE", "BLT", "BGE"}:
        return f"{mnemonic} {register(rd)}, {register(rs1)}, {sign_extend(imm16, 16)}"
    if mnemonic in {"J", "JAL"}:
        return f"{mnemonic} {sign_extend(word & 0x03FFFFFF, 26)}"
    return invalid(word)


def disassemble_bytes(image: bytes) -> str:
    if len(image) % 4:
        raise ValueError("binary image size must be divisible by 4 bytes")
    return "\n".join(disassemble_word(int.from_bytes(image[offset:offset + 4], "little"))
                     for offset in range(0, len(image), 4)) + ("\n" if image else "")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Disassemble a raw Mini32 little-endian ROM image.")
    parser.add_argument("input", type=Path, help="binary image")
    parser.add_argument("-o", "--output", type=Path, help="write assembly to this file")
    args = parser.parse_args(argv)
    try:
        output = disassemble_bytes(args.input.read_bytes())
        if args.output:
            args.output.write_text(output, encoding="utf-8")
        else:
            print(output, end="")
    except (OSError, ValueError) as error:
        print(f"{args.input}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
