    ORG 8000H

counter: EQU 6000H

init
    LD A,1
    LD BC,(counter)
    JP loop
    RET
loop
    LD (BC),A
    INC A
    INC BC
    CP 99
    JP C, fizzend
    JP loop
    RET
fizzend
    HALT
    RET

    END