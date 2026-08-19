# Mini32 Assembler and Disassembler

The tools implement the machine-code formats in `docs/isa.md`; that document is authoritative.

```powershell
python assembler/assembler.py programs/arithmetic_loop.asm -o build/arithmetic_loop.bin
python assembler/disassembler.py build/arithmetic_loop.bin
```

The assembler requires `-o` and produces raw little-endian 32-bit instruction words. It accepts uppercase or lowercase mnemonics/registers, `#` comments, blank lines, labels, and labels followed by an instruction on the same line. Labels use `[A-Za-z_][A-Za-z0-9_]*` and are resolved in two passes.

Registers are `r0` through `r31`; `zero`, `sp`, and `ra` alias `r0`, `r30`, and `r31`. `RET` expands to `JR r31`. `.word value` emits one raw 32-bit word.

`ADDI`, `LW`, and `SW` use signed 16-bit immediates. `ANDI`, `ORI`, `XORI`, and `LUI` use unsigned 16-bit values. Memory syntax is `offset(base)`, such as `SW r2, -4(sp)`.

Branches and `J`/`JAL` accept labels or signed numeric **instruction-word displacements**. For a label, the assembler encodes `(target - (PC + 4)) / 4`; the disassembler emits numeric displacements so its output is directly reassemblable.

Ordinary errors report source path, line number, and a concise reason. The disassembler writes `.word 0xXXXXXXXX` for malformed or unknown instruction words and rejects binary files whose size is not divisible by four.
