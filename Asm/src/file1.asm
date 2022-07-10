; 99 Bottles of Beer program in Zilgo Z80 assembly language.

     org 1000

sum: EQU 0

loop
    LD a,5
    LD b,a
    ADD a,b
    LD (sum),a
    END
