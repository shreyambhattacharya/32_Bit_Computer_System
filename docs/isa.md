# Mini32 ISA Specification (v0.1)

## Architectural state

- Thirty-two 32-bit general-purpose registers: `r0` through `r31`.
- `r0` always reads as `0x00000000`; writes to it have no effect.
- `PC` is a separate 32-bit byte address, reset to `0x00000000`.
- `r30` (`sp`) and `r31` (`ra`) are ABI conventions. `JAL` writes `PC + 4` to `r31`; `RET` is assembler syntax for `JR r31`.
- All arithmetic is two's-complement 32-bit wrapping arithmetic. `SLT`, `BLT`, and `BGE` compare signed values.

## Encoding

Every instruction is one 32-bit little-endian word, aligned to four bytes. The primary opcode is bits `[31:26]`.

| Format | 31:26 | 25:21 | 20:16 | 15:11 | 10:0 |
| --- | --- | --- | --- | --- |
| R | opcode | rd | rs1 | rs2 | zero |
| I | opcode | rd | rs1 | imm16 | imm16 |
| S | opcode | rs2 | rs1 | imm16 | imm16 |
| B | opcode | rs1 | rs2 | imm16 | imm16 |
| J | opcode | signed imm26 | signed imm26 | signed imm26 | signed imm26 |
| JR | opcode | rs1 | zero | zero | zero |

The duplicated `imm16` entries above mean the contiguous field `[15:0]`; they are shown over multiple table columns only to align formats. R-format reserved bits `[10:0]` must be zero.

## Opcode allocation

| Hex | Mnemonic | Format | Semantics |
| --- | --- | --- | --- |
| `00` | `NOP` | R | No operation; all remaining bits zero. |
| `01` | `ADD rd, rs1, rs2` | R | `rd = rs1 + rs2` |
| `02` | `SUB rd, rs1, rs2` | R | `rd = rs1 - rs2` |
| `03` | `AND rd, rs1, rs2` | R | bitwise AND |
| `04` | `OR rd, rs1, rs2` | R | bitwise OR |
| `05` | `XOR rd, rs1, rs2` | R | bitwise XOR |
| `06` | `SLT rd, rs1, rs2` | R | signed `rs1 < rs2` as 0 or 1 |
| `07` | `SHL rd, rs1, rs2` | R | `rs1 << (rs2[4:0])` |
| `08` | `SHR rd, rs1, rs2` | R | logical `rs1 >> (rs2[4:0])` |
| `09` | `ADDI rd, rs1, imm16` | I | `rd = rs1 + signext(imm16)` |
| `0A` | `ANDI rd, rs1, imm16` | I | `rd = rs1 & zeroext(imm16)` |
| `0B` | `ORI rd, rs1, imm16` | I | `rd = rs1 | zeroext(imm16)` |
| `0C` | `XORI rd, rs1, imm16` | I | `rd = rs1 ^ zeroext(imm16)` |
| `0D` | `LUI rd, imm16` | I | `rd = imm16 << 16`; `rs1` must be zero |
| `0E` | `LW rd, imm16(rs1)` | I | `rd = load32(rs1 + signext(imm16))` |
| `0F` | `SW rs2, imm16(rs1)` | S | `store32(rs1 + signext(imm16), rs2)` |
| `10` | `BEQ rs1, rs2, label` | B | branch if equal |
| `11` | `BNE rs1, rs2, label` | B | branch if not equal |
| `12` | `BLT rs1, rs2, label` | B | branch if signed less than |
| `13` | `BGE rs1, rs2, label` | B | branch if signed greater/equal |
| `14` | `J label` | J | unconditional PC-relative jump |
| `15` | `JAL label` | J | set `r31 = PC + 4`, then PC-relative jump |
| `16` | `JR rs1` | JR | `PC = rs1` |
| `17` | `HALT` | R | stop the CPU after the instruction retires |

`NOP` and `HALT` each have exactly one legal encoding: their opcode in bits `[31:26]` and all remaining bits `[25:0]` clear. Unallocated opcodes are illegal and fault deterministically. `MUL`, byte accesses, interrupts, and system instructions are deliberately unallocated in v0.1.

## Immediates, control flow, and addresses

`ADDI`, `LW`, and `SW` sign-extend `imm16`. Logical immediate instructions zero-extend it. `LUI` is used with `ORI` to form full addresses such as `0x20000000`.

For a branch, the encoded signed `imm16` is an instruction-word displacement. The target is `PC + 4 + (signext(imm16) << 2)`. `J` and `JAL` use the same rule with signed `imm26`. This gives branches a range of ±128 KiB and jumps a range of ±128 MiB, without absolute-address relocation complexity.

`LW` and `SW` are the initial data-access instructions. Their effective address must be 4-byte aligned. The address space itself is byte-addressable, and word values are stored little-endian: the least-significant byte lives at the lowest address. Byte/halfword accesses are a later compatible extension, not part of the minimum computer.

## Assembly examples

```asm
    # r2 = 45
    ADDI r1, r0, 10
    ADDI r2, r0, 0
loop:
    ADD  r2, r2, r1
    ADDI r1, r1, -1
    BNE  r1, r0, loop
    HALT
```

```asm
    # Send character 'A' to the UART data register.
    LUI  r1, 0x2000
    ADDI r2, r0, 65
    SW   r2, 0(r1)
    HALT
```
