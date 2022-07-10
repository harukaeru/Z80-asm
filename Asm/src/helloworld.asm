    ORG 9000H

LOC_BEGIN: EQU 0H

init
    LD BC, LOC_BEGIN
    LD D, 0
    JP loop
    RET

loop
    LD A,'H'
    LD (BC),A
    INC BC
    
    LD A,'e'
    LD (BC),A
    INC BC
    
    LD A,'l'
    LD (BC),A
    INC BC

    LD A,'l'
    LD (BC),A
    INC BC

    LD A,'o'
    LD (BC),A
    INC BC

    LD A,','
    LD (BC),A
    INC BC

    LD A,' '
    LD (BC),A
    INC BC

    LD A,'W'
    LD (BC),A
    INC BC

    LD A,'o'
    LD (BC),A
    INC BC

    LD A,'r'
    LD (BC),A
    INC BC

    LD A,'l'
    LD (BC),A
    INC BC

    LD A,'d'
    LD (BC),A
    INC BC

    LD A,'!'
    LD (BC),A
    INC BC

    INC D
    LD A,D
    CP 100
    JP C,loop

    RET

    END
