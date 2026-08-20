import subprocess
import sys
import unittest
from pathlib import Path


class SimulatorCliTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if len(sys.argv) != 5:
            raise unittest.SkipTest("simulator CLI arguments are supplied by CTest")
        cls.simulator = Path(sys.argv[1])
        cls.hello = Path(sys.argv[2])
        cls.infinite = Path(sys.argv[3])
        cls.illegal = Path(sys.argv[4])

    def run_simulator(self, image: Path, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([str(self.simulator), str(image), *args], capture_output=True,
                              text=True, check=False)

    def test_hello_uart_stdout_is_guest_only(self) -> None:
        result = self.run_simulator(self.hello)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "Hello Mini32!\n")
        self.assertIn("CPU halted after", result.stderr)

    def test_instruction_limit_is_a_host_failure(self) -> None:
        result = self.run_simulator(self.infinite, "--max-instructions", "3")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIn("instruction limit exceeded", result.stderr)

    def test_illegal_guest_instruction_reports_cpu_fault(self) -> None:
        result = self.run_simulator(self.illegal)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIn("IllegalInstruction", result.stderr)
        self.assertIn("PC:", result.stderr)
        self.assertIn("instruction:", result.stderr)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
