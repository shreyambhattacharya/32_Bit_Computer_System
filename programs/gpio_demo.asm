    # GPIO OUTPUT = 0x0000000A, DIRECTION = 0x0000000F.
    LUI  r1, 0x2000
    ORI  r1, r1, 0x0200
    ADDI r2, r0, 15
    SW   r2, 8(r1)
    ADDI r3, r0, 10
    SW   r3, 4(r1)
    LW   r4, 4(r1)
    LW   r5, 8(r1)
    LUI  r6, 0x1000
    SW   r4, 0(r6)
    SW   r5, 4(r6)
    HALT
