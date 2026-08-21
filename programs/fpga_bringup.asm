    # Tang Nano 20K bring-up: GPIO pattern, Debug VALUE, and physical UART.
    LUI  r1, 0x2000
    ORI  r1, r1, 0x0200
    LUI  r5, 0x2000
    ADDI r2, r0, 15
    SW   r2, 8(r1)
    ADDI r2, r0, 5
    SW   r2, 4(r1)

    LUI  r3, 0x2000
    ORI  r3, r3, 0x0300
    LUI  r4, 0x5441
    ORI  r4, r4, 0x4E47
    SW   r4, 0(r3)

    ADDI r2, r0, 77
    SW   r2, 0(r5)
    ADDI r2, r0, 105
    SW   r2, 0(r5)
    ADDI r2, r0, 110
    SW   r2, 0(r5)
    ADDI r2, r0, 105
    SW   r2, 0(r5)
    ADDI r2, r0, 51
    SW   r2, 0(r5)
    ADDI r2, r0, 50
    SW   r2, 0(r5)
    ADDI r2, r0, 32
    SW   r2, 0(r5)
    ADDI r2, r0, 84
    SW   r2, 0(r5)
    ADDI r2, r0, 97
    SW   r2, 0(r5)
    ADDI r2, r0, 110
    SW   r2, 0(r5)
    ADDI r2, r0, 103
    SW   r2, 0(r5)
    ADDI r2, r0, 32
    SW   r2, 0(r5)
    ADDI r2, r0, 78
    SW   r2, 0(r5)
    ADDI r2, r0, 97
    SW   r2, 0(r5)
    ADDI r2, r0, 110
    SW   r2, 0(r5)
    ADDI r2, r0, 111
    SW   r2, 0(r5)
    ADDI r2, r0, 32
    SW   r2, 0(r5)
    ADDI r2, r0, 50
    SW   r2, 0(r5)
    ADDI r2, r0, 48
    SW   r2, 0(r5)
    ADDI r2, r0, 75
    SW   r2, 0(r5)
    ADDI r2, r0, 10
    SW   r2, 0(r5)

    ADDI r2, r0, 10
    SW   r2, 4(r1)
    HALT
