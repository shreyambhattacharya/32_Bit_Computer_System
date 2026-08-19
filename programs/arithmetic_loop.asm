# Expected on HALT: r2 = 6
ADDI r1, r0, 3
ADDI r2, r0, 0

loop:
    ADD r2, r2, r1
    ADDI r1, r1, -1
    BNE r1, r0, loop

HALT
