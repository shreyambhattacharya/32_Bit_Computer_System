# Deterministic v0.1 ISA coverage for C++/RTL retirement-trace comparison.
NOP
LUI r1, 0x1000
ADDI r0, r0, 1
ADDI r2, r0, 5
ADDI r3, r0, 3
ADD r4, r2, r3
SUB r5, r2, r3
AND r6, r2, r3
OR r7, r2, r3
XOR r8, r2, r3
SLT r9, r3, r2
SHL r10, r3, r2
SHR r11, r10, r3
ANDI r12, r7, 3
ORI r13, r0, 0x1234
XORI r14, r13, 0x00FF
SW r4, 0(r1)
LW r15, 0(r1)
BEQ r15, r4, beq_taken
ADDI r16, r0, 99
beq_taken:
BNE r15, r4, bne_wrong
BLT r3, r2, blt_taken
ADDI r16, r0, 98
blt_taken:
BGE r2, r3, bge_taken
ADDI r16, r0, 97
bge_taken:
J jump_target
ADDI r16, r0, 96
jump_target:
JAL subroutine
ADDI r17, r16, 1
HALT
subroutine:
ADDI r16, r0, 77
JR r31
bne_wrong:
ADDI r16, r0, 95
HALT
