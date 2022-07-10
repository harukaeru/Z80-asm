     ORG 1000

counter: EQU 0H

main
    LD a,5
    LD b,a
    ADD a,b
    LD (counter),a
    RET
loop
    LD a,5
    RET
fizzend
    LD a,5
    RET
