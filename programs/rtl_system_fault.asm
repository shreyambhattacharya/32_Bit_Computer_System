# Expected fault: unmapped load at 0x30000000.
LUI r1, 0x3000
LW r2, 0(r1)
HALT
