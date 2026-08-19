# Expected on HALT: r1 = 3, r2 = 9, r3 = 7
ADDI r1, r0, 3
JAL function
ADDI r2, r0, 9
HALT

function:
    ADDI r3, r0, 7
    RET
