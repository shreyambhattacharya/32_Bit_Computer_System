"""Authoritative Python encoding definitions for the documented Mini32 v0.1 ISA."""

from enum import IntEnum


class Opcode(IntEnum):
    NOP = 0x00
    ADD = 0x01
    SUB = 0x02
    AND = 0x03
    OR = 0x04
    XOR = 0x05
    SLT = 0x06
    SHL = 0x07
    SHR = 0x08
    ADDI = 0x09
    ANDI = 0x0A
    ORI = 0x0B
    XORI = 0x0C
    LUI = 0x0D
    LW = 0x0E
    SW = 0x0F
    BEQ = 0x10
    BNE = 0x11
    BLT = 0x12
    BGE = 0x13
    J = 0x14
    JAL = 0x15
    JR = 0x16
    HALT = 0x17


R_INSTRUCTIONS = frozenset({"ADD", "SUB", "AND", "OR", "XOR", "SLT", "SHL", "SHR"})
SIGNED_I_INSTRUCTIONS = frozenset({"ADDI", "LW", "SW"})
UNSIGNED_I_INSTRUCTIONS = frozenset({"ANDI", "ORI", "XORI", "LUI"})
BRANCH_INSTRUCTIONS = frozenset({"BEQ", "BNE", "BLT", "BGE"})
JUMP_INSTRUCTIONS = frozenset({"J", "JAL"})
REGISTER_ALIASES = {"zero": 0, "sp": 30, "ra": 31}


def sign_extend(value: int, width: int) -> int:
    """Return an unsigned field interpreted as a signed two's-complement value."""
    sign_bit = 1 << (width - 1)
    return value - (1 << width) if value & sign_bit else value
