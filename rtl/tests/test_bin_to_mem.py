"""Unit tests for the raw Mini32 image to ROM .memh converter."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from bin_to_mem import ROM_SIZE_BYTES, ROM_WORD_COUNT, convert_image  # noqa: E402


class BinToMemTests(unittest.TestCase):
    def test_little_endian_words(self) -> None:
        words = convert_image(bytes.fromhex("78 56 34 12 EF CD AB 90")).splitlines()
        self.assertEqual(len(words), ROM_WORD_COUNT)
        self.assertEqual(words[:2], ["12345678", "90ABCDEF"])
        self.assertEqual(set(words[2:]), {"00000000"})

    def test_rejects_non_word_sized_input(self) -> None:
        with self.assertRaisesRegex(ValueError, "divisible"):
            convert_image(b"\x00\x01\x02")

    def test_rejects_image_larger_than_rom(self) -> None:
        with self.assertRaisesRegex(ValueError, "64 KiB"):
            convert_image(bytes(ROM_SIZE_BYTES + 4))


if __name__ == "__main__":
    unittest.main()
