    ORG 8000H

START: EQU 1
loc: EQU 6000H

init
    LD A,start
    LD BC,loc
    JP loop
    RET
loop
    LD (BC),A
    INC A
    INC BC
    CP 90
    JP C,loop
    RET

    END