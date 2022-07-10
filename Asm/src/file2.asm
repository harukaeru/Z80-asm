    ORG 9000H

    LD A,(0140H)
    ADD A,C
    LD (9100H),A
    HALT
