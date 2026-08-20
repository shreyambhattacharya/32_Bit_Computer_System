    LUI  r1, 0x2000
    ADDI r1, r1, 0x0300
    LUI  r2, 0x1234
    ORI  r2, r2, 0x5678
    SW   r2, 0(r1)
    LW   r3, 0(r1)
    HALT
