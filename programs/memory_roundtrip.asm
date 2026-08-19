# Expected on HALT: r3 = 42 and RAM[0x10000000] = 42
LUI r1, 0x1000
ADDI r2, r0, 42
SW r2, 0(r1)
LW r3, 0(r1)
HALT
