    # TX-only UART demonstration: each word store emits its low byte.
    LUI  r1, 0x2000
    ADDI r2, r0, 72
    SW   r2, 0(r1)
    ADDI r2, r0, 101
    SW   r2, 0(r1)
    ADDI r2, r0, 108
    SW   r2, 0(r1)
    SW   r2, 0(r1)
    ADDI r2, r0, 111
    SW   r2, 0(r1)
    ADDI r2, r0, 32
    SW   r2, 0(r1)
    ADDI r2, r0, 77
    SW   r2, 0(r1)
    ADDI r2, r0, 105
    SW   r2, 0(r1)
    ADDI r2, r0, 110
    SW   r2, 0(r1)
    ADDI r2, r0, 105
    SW   r2, 0(r1)
    ADDI r2, r0, 51
    SW   r2, 0(r1)
    ADDI r2, r0, 50
    SW   r2, 0(r1)
    ADDI r2, r0, 33
    SW   r2, 0(r1)
    ADDI r2, r0, 10
    SW   r2, 0(r1)
    HALT
