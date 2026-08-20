    # UART STATUS is always ready; Debug VALUE is persistent read/write state.
    LUI  r1, 0x2000
    LW   r2, 4(r1)
    ORI  r3, r1, 0x0300
    LUI  r4, 0xCAFE
    ORI  r4, r4, 0xBEEF
    SW   r4, 0(r3)
    LW   r5, 0(r3)
    LUI  r6, 0x1000
    SW   r2, 0(r6)
    SW   r5, 4(r6)
    HALT
