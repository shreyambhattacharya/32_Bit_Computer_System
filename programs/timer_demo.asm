    # Tick ordering: enabling CONTROL retires and becomes counter tick 1.
    LUI  r1, 0x2000
    ORI  r1, r1, 0x0100
    SW   r0, 0(r1)          # COUNTER = 0 while disabled
    ADDI r2, r0, 5
    SW   r2, 4(r1)          # COMPARE = 5 while disabled
    ADDI r2, r0, 1
    SW   r2, 8(r1)          # enable, then tick -> COUNTER = 1
    NOP                      # tick -> 2
    NOP                      # tick -> 3
    LW   r3, 0(r1)          # observes 3, then tick -> 4
    LW   r4, 12(r1)         # observes MATCH = 0, then tick -> 5
    LW   r5, 12(r1)         # observes MATCH = 1, then tick -> 6
    LUI  r6, 0x1000         # tick -> 7
    SW   r3, 0(r6)          # tick -> 8
    SW   r4, 4(r6)          # tick -> 9
    SW   r5, 8(r6)          # tick -> 10
    HALT                     # tick -> 11
