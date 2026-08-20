from __future__ import annotations

import unittest

from verification.differential import DifferentialMismatch, TraceError, compare_traces, parse_trace


RETIRE = '{"type":"retire","index":0,"pc":"00000000","instruction":"00000000","next_pc":"00000004","reg_write":false,"rd":0,"reg_value":"00000000","mem_write":false,"mem_addr":"00000000","mem_value":"00000000"}'
FINAL = '{"type":"final","status":"halted","pc":"00000004","retired":1,"uart_tx":"","debug_value":"00000000"}'


class DifferentialTests(unittest.TestCase):
    def trace(self, retire: str = RETIRE, final: str = FINAL):
        return parse_trace(f"{retire}\n{final}\n")

    def test_exact_match(self) -> None:
        compare_traces(self.trace(), self.trace())

    def test_retirement_mismatches(self) -> None:
        for field, old, new in (("pc", "00000000", "00000004"), ("instruction", "00000000", "fc000000"),
                                ("next_pc", "00000004", "00000008"), ("rd", "0", "1"),
                                ("reg_value", "00000000", "00000001"), ("mem_write", "false", "true")):
            with self.subTest(field=field):
                changed = RETIRE.replace(f'"{field}":{old}' if field in {"rd"} else f'"{field}":"{old}"',
                                         f'"{field}":{new}' if field in {"rd"} else f'"{field}":"{new}"')
                if field == "mem_write": changed = RETIRE.replace('"mem_write":false', '"mem_write":true')
                if field in {"rd", "reg_value"}:
                    changed = RETIRE.replace('"reg_write":false', '"reg_write":true').replace(
                        f'"{field}":{old}' if field == "rd" else f'"{field}":"{old}"',
                        f'"{field}":{new}' if field == "rd" else f'"{field}":"{new}"')
                with self.assertRaises(DifferentialMismatch):
                    compare_traces(self.trace(), self.trace(changed))

        memory_retire = RETIRE.replace('"mem_write":false', '"mem_write":true')
        for field, changed_value in (("mem_addr", "10000000"), ("mem_value", "00000001")):
            with self.subTest(field=field):
                changed = memory_retire.replace(f'"{field}":"00000000"', f'"{field}":"{changed_value}"')
                with self.assertRaises(DifferentialMismatch):
                    compare_traces(self.trace(memory_retire), self.trace(changed))

    def test_fault_and_length_mismatches(self) -> None:
        fault = '{"type":"final","status":"faulted","pc":"00000004","retired":1,"uart_tx":"","debug_value":"00000000","fault":"UnmappedLoad","fault_pc":"00000004","fault_instruction":"24000000","fault_address_valid":true,"fault_address":"30000000"}'
        changed = fault.replace("UnmappedLoad", "MisalignedLoad")
        with self.assertRaises(DifferentialMismatch): compare_traces(self.trace(final=fault), self.trace(final=changed))
        short_trace = parse_trace('{"type":"final","status":"halted","pc":"00000000","retired":0,"uart_tx":"","debug_value":"00000000"}\n')
        with self.assertRaises(DifferentialMismatch): compare_traces(self.trace(), short_trace)

    def test_rejects_malformed_trace_records(self) -> None:
        for text in ("not json\n", "{}\n", RETIRE.replace("00000000", "0", 1) + "\n" + FINAL,
                     RETIRE.replace('"type":"retire"', '"type":"unknown"') + "\n" + FINAL):
            with self.subTest(text=text):
                with self.assertRaises(TraceError): parse_trace(text)

    def test_normalizes_hexadecimal_case(self) -> None:
        uppercase = RETIRE.replace("00000000", "ABCDEF01", 1).replace("00000004", "ABCDEF05", 1)
        uppercase_final = ('{"type":"final","status":"halted","pc":"ABCDEF05","retired":1,'
                           '"uart_tx":"48656C6C6F","debug_value":"DEADBEEF"}')
        records = parse_trace(f"{uppercase}\n{uppercase_final}\n")
        self.assertEqual(records[0]["pc"], "abcdef01")
        self.assertEqual(records[-1]["pc"], "abcdef05")
        self.assertEqual(records[-1]["uart_tx"], "48656c6c6f")
        self.assertEqual(records[-1]["debug_value"], "deadbeef")

    def test_rejects_invalid_hexadecimal_lengths_and_characters(self) -> None:
        for field, replacement in (("pc", "0000000"), ("pc", "000000000"),
                                   ("debug_value", "0000000g"), ("uart_tx", "0"),
                                   ("uart_tx", "zz")):
            with self.subTest(field=field, replacement=replacement):
                original = "" if field == "uart_tx" else ("00000004" if field == "pc" else "00000000")
                malformed = FINAL.replace(f'"{field}":"{original}"', f'"{field}":"{replacement}"')
                with self.assertRaises(TraceError):
                    parse_trace(f"{RETIRE}\n{malformed}\n")


if __name__ == "__main__":
    unittest.main()
