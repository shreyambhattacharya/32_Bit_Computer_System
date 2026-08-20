# Expected on HALT: r3/r4 = 6 and r5/r6 = 7; RAM words 0/1 hold 6/7.
LUI r1, 0x1000
ADDI r2, r0, 3
ADDI r3, r0, 0
loop:
ADD r3, r3, r2
ADDI r2, r2, -1
BNE r2, r0, loop
SW r3, 0(r1)
LW r4, 0(r1)
ADDI r5, r4, 1
SW r5, 4(r1)
LW r6, 4(r1)
HALT
