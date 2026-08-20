import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "assembler"))

from assembler import AssemblyError, assemble_text  # noqa: E402
from disassembler import disassemble_bytes, disassemble_word  # noqa: E402
from mini32_isa import Opcode  # noqa: E402


def words(image: bytes) -> list[int]:
    return [int.from_bytes(image[index:index + 4], "little") for index in range(0, len(image), 4)]


class AssemblerEncodingTests(unittest.TestCase):
    def test_rtl_opcode_constants_match_the_python_isa(self) -> None:
        package = (ROOT / "rtl" / "include" / "mini32_pkg.sv").read_text(encoding="utf-8")
        actual = dict(re.findall(r"\bOP_([A-Z]+)\s*=\s*6'h([0-9A-Fa-f]{2})", package))
        expected = {opcode.name: f"{int(opcode):02X}" for opcode in Opcode}
        self.assertEqual(actual, expected)

    def test_opcode_values_match_the_documented_isa(self) -> None:
        expected = [
            ("NOP", 0x00), ("ADD", 0x01), ("SUB", 0x02), ("AND", 0x03),
            ("OR", 0x04), ("XOR", 0x05), ("SLT", 0x06), ("SHL", 0x07),
            ("SHR", 0x08), ("ADDI", 0x09), ("ANDI", 0x0A), ("ORI", 0x0B),
            ("XORI", 0x0C), ("LUI", 0x0D), ("LW", 0x0E), ("SW", 0x0F),
            ("BEQ", 0x10), ("BNE", 0x11), ("BLT", 0x12), ("BGE", 0x13),
            ("J", 0x14), ("JAL", 0x15), ("JR", 0x16), ("HALT", 0x17),
        ]
        self.assertEqual([(opcode.name, int(opcode)) for opcode in Opcode], expected)

    def test_all_opcodes_have_documented_encodings(self) -> None:
        source = """\
NOP
ADD r3, r1, r2
SUB r3, r1, r2
AND r3, r1, r2
OR r3, r1, r2
XOR r3, r1, r2
SLT r3, r1, r2
SHL r3, r1, r2
SHR r3, r1, r2
ADDI r3, r1, -1
ANDI r3, r1, 0xFFFF
ORI r3, r1, 0xFFFF
XORI r3, r1, 0xFFFF
LUI r3, 0x1000
LW r3, -4(r1)
SW r3, -4(r1)
BEQ r1, r2, -1
BNE r1, r2, -1
BLT r1, r2, -1
BGE r1, r2, -1
J -1
JAL -1
JR r31
HALT
"""
        r_word = (3 << 21) | (1 << 16) | (2 << 11)
        expected = [
            0,
            (Opcode.ADD << 26) | r_word, (Opcode.SUB << 26) | r_word,
            (Opcode.AND << 26) | r_word, (Opcode.OR << 26) | r_word,
            (Opcode.XOR << 26) | r_word, (Opcode.SLT << 26) | r_word,
            (Opcode.SHL << 26) | r_word, (Opcode.SHR << 26) | r_word,
            (Opcode.ADDI << 26) | (3 << 21) | (1 << 16) | 0xFFFF,
            (Opcode.ANDI << 26) | (3 << 21) | (1 << 16) | 0xFFFF,
            (Opcode.ORI << 26) | (3 << 21) | (1 << 16) | 0xFFFF,
            (Opcode.XORI << 26) | (3 << 21) | (1 << 16) | 0xFFFF,
            (Opcode.LUI << 26) | (3 << 21) | 0x1000,
            (Opcode.LW << 26) | (3 << 21) | (1 << 16) | 0xFFFC,
            (Opcode.SW << 26) | (3 << 21) | (1 << 16) | 0xFFFC,
            (Opcode.BEQ << 26) | (1 << 21) | (2 << 16) | 0xFFFF,
            (Opcode.BNE << 26) | (1 << 21) | (2 << 16) | 0xFFFF,
            (Opcode.BLT << 26) | (1 << 21) | (2 << 16) | 0xFFFF,
            (Opcode.BGE << 26) | (1 << 21) | (2 << 16) | 0xFFFF,
            (Opcode.J << 26) | 0x03FFFFFF,
            (Opcode.JAL << 26) | 0x03FFFFFF,
            (Opcode.JR << 26) | (31 << 21),
            Opcode.HALT << 26,
        ]
        self.assertEqual(words(assemble_text(source)), [int(word) for word in expected])

    def test_aliases_labels_memory_and_ret(self) -> None:
        source = """\
start: ADDI sp, zero, 8
SW ra, -4(sp)
J done
loop: NOP
done: RET
"""
        assembled = words(assemble_text(source))
        self.assertEqual(assembled[0], (Opcode.ADDI << 26) | (30 << 21) | 8)
        self.assertEqual(assembled[1], (Opcode.SW << 26) | (31 << 21) | (30 << 16) | 0xFFFC)
        self.assertEqual(assembled[2], (Opcode.J << 26) | 1)
        self.assertEqual(assembled[4], (Opcode.JR << 26) | (31 << 21))

    def test_multiple_labels_and_word_directive(self) -> None:
        image = assemble_text("first: second: .word 0x12345678\nJ first\n")
        self.assertEqual(words(image), [0x12345678, (Opcode.J << 26) | 0x03FFFFFE])

    def test_label_displacements_and_boundaries(self) -> None:
        image = assemble_text("BNE r1, r0, loop\nNOP\nloop: J -1\n")
        self.assertEqual(words(image)[0] & 0xFFFF, 1)
        self.assertEqual(words(image)[2] & 0x03FFFFFF, 0x03FFFFFF)
        self.assertEqual(words(assemble_text("ADDI r1, r0, -32768\nADDI r2, r0, 32767\n"))[0] & 0xFFFF, 0x8000)
        self.assertEqual(words(assemble_text("BNE r1, r2, -32768\nBNE r1, r2, 32767\n"))[1] & 0xFFFF, 0x7FFF)
        self.assertEqual(words(assemble_text("J -33554432\nJ 33554431\n"))[1] & 0x03FFFFFF, 0x01FFFFFF)

    def test_invalid_input_reports_assembly_error(self) -> None:
        invalid_sources = [
            "NOPE r1, r2, r3", "ADD r1, r2", "ADDI r32, r0, 1", "ANDI r1, r0, -1",
            "ADDI r1, r0, 32768", "LW r1, 4r2", "label: NOP\nlabel: HALT",
            "J missing", "BNE r1, r2, 32768", "J 33554432", "bad-label: NOP",
        ]
        for source in invalid_sources:
            with self.subTest(source=source):
                with self.assertRaises(AssemblyError):
                    assemble_text(source, "invalid.asm")


class DisassemblerTests(unittest.TestCase):
    def test_round_trip_all_legal_instructions(self) -> None:
        source = """\
NOP
ADD r3, r1, r2
SUB r3, r1, r2
AND r3, r1, r2
OR r3, r1, r2
XOR r3, r1, r2
SLT r3, r1, r2
SHL r3, r1, r2
SHR r3, r1, r2
ADDI r3, r1, -1
ANDI r3, r1, 0xFFFF
ORI r3, r1, 0xFFFF
XORI r3, r1, 0xFFFF
LUI r3, 0x1000
LW r3, -4(r1)
SW r3, -4(r1)
BEQ r1, r2, -1
BNE r1, r2, -1
BLT r1, r2, -1
BGE r1, r2, -1
J -1
JAL -1
JR r31
HALT
"""
        image = assemble_text(source)
        self.assertEqual(assemble_text(disassemble_bytes(image)), image)

    def test_invalid_words_and_short_files_are_safe(self) -> None:
        self.assertEqual(disassemble_word(0xFC000000), ".word 0xFC000000")
        self.assertEqual(disassemble_word((Opcode.ADD << 26) | 1), ".word 0x04000001")
        self.assertEqual(disassemble_word((Opcode.JR << 26) | (1 << 20)), ".word 0x58100000")
        self.assertEqual(disassemble_word((Opcode.LUI << 26) | (1 << 16)), ".word 0x34010000")
        self.assertEqual(disassemble_word((Opcode.HALT << 26) | (1 << 21)), ".word 0x5C200000")
        malformed = (Opcode.ADD << 26) | 1
        self.assertEqual(assemble_text(disassemble_word(malformed)), malformed.to_bytes(4, "little"))
        with self.assertRaises(ValueError):
            disassemble_bytes(b"\x00")


if __name__ == "__main__":
    unittest.main()
