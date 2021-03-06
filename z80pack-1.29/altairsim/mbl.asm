; MBL - MULTI BOOT LOADER FOR THE ALTAIR 8800
;
; DISAASEMBLED AND COMMENTED BY GEOFF HARRISON (GHOV SOLIVANT COM)
;
; THIS IS A BOOT LOADER THAT CAN BE LOACATED IN ROM AND WHICH
; CAN READ ANY OF THE PUNCHED TAPE FORMATS THAT MITS DESIGNED.
; IT RUNS OUT OF ROM BY CREATING A READBYTE ROUTINE IN RAM WHICH
; IS CUSTOMIZED FOR WHATEVER I/O BOARD THE USER SPECIFIES AT
; RUN TIME ON THE FRONT PANEL SWITCHES. IT THEN SKIPS OVER THE
; LEADIN BYTES AND THE SECOND STAGE LOADER WHICH ALWAYS PRECEED
; THE PAYLOAD ON A MITS TAPE.  SINCE IT DOESN'T USE THE
; SECOND STAGE LOADER, IT DOESN'T CARE WHICH OF SEVERAL POSSIBLE
; VERSIONS OF TAPE IT IS LOADING.  NORMALLY YOU HAVE TO BE SURE
; TO USE THE CORRECT 1ST STAGE LOADER FOR THE TAPE YOU ARE LOADING,
; WITH THE MBL IT DOESN'T MATTER.  AFTER SKIPPING THE 2ND STAGE
; LOADER ON THE TAPE, IT STARTS READING AND STORING PAYLOAD
; BYTES AND CHECKING THAT THE CHECKSUM IS CORRECT FOR EACH PACKET
; OF BYTES READ.  WHEN THE ENTIRE PAYLOAD HAS BEEN READ INTO MEMORY,
; IT READS THE ENTRY POINT FOR THE PROGRAM FROM THE TAPE AND JUMPS
; TO THAT LOCATION.
;
; THE FORMAT OF A MITS PAPER TAPE IS:
;       - SOME NUMBER OF IDENTICAL BYTES, EACH CONTAINING
;               THE LENGTH (N) OF THE STAGE2 LOADER
;       - N BYTES OF STAGE 2 LOADER
;       - OPTIONALLY SOME NUMBER OF NULLS
;       - ONE OR MORE LOAD RECORDS (SEE BELOW)
;       - AN EOF RECORD (SEE BELOW)
;
; A LOAD RECORD CONSISTS OF:
;       074     - SYNC BYTE (HEX 03CH)
;       NNN     - # BYTES IN RECORD
;       LLL     - LOW BYTE OF LOAD ADDRESS
;       HHH     - HIGH BYTE OF LOAD ADDRESS
;   <NNN BYTES> - NNN BYTES OF PROGRAM DATA (THE PAYLOAD)
;       CCC     - CHECKSUM BYTE
;                (CHECKSUM INCLUDES LLL & HHH)
; THERE WILL BE 1 OR MORE PROG LOAD RECORDS,
; EACH ONE WITH UP TO 256 BYTES OF PAYLOAD
; BYTES.
;
; THE EOF RECORD CONSISTS OF:
;       0170    - SYNC BYTE (HEX 078H)
;       LLL     - LOW BYTE OF START ADDRESS
;       HHH     - HIGH BYTE OF START ADDRESS
;
; BEFORE EXECUTING THIS PROGRAM, THE FRONT PANEL SENSE SWITCHES
; MUST BE SET TO INDICATE WHAT DEVICE TO READ THE TAPE FROM AND
; WHAT DEVICE THE TERMINAL IS ATTACHED TO.  THIS PROGRAM USES
; A11..A8 TO DETERMINE THE DEVICE ATTACHED TO THE TAPE READER.
; IF THE PAYLOAD IS NOT EARLIER THAN BASIC 4.0, IT USES A15..A12
; TO DETERMINE WHERE THE TERMINAL DEVICE IS.
; POSSIBLE SWITCH VALUES ARE
;
; DEVICE                SWITCH VALUE
; 2SIO (2 STOP BITS)      0000B
; 2SIO (1 STOP BIT)       0001B
; SIO                     0010B
; ACR                     0011B
; 4PIO                    0100B
; PIO                     0101B
; HSR                     0110B
;
; IF A VALUE LARGER THAN 7 IS ENTERED THIS PROGRAM WILL RETURN
; AN ERROR.
;
; PRIOR TO BASIC 4.0, MITS USED DIFFERENT SENSE SWITCH SETTINGS
; TO SPECIFY THE TERMINAL DEVICE.  YOU SHOULD STILL BE ABLE TO
; LOAD AN OLDER TAPE WITH THIS LOADER BY SETTING THE SWITCHES AS
; ABOVE, STOPPING THE PROGRAM AFTER IT LOADS AND STARTS, CHANGING
; THE SENSE SWITCHES (SEE THE APPROPRIATE MITS MANUAL FOR SWITCH
; SETTINGS) AND RESTARTING THE PROGRAM AT ITS ENTRY POINT (E.G.
; 00000H FOR BASIC 3.2).
; 
; THIS LISTING WAS GENERATED FROM A HEX DUMP OF MBL PROVIDED BY
; GRANT STOCKLY.  THE ASSEMBLY CODE AND COMMENTS WERE REVERSE
; ENGINEERED FROM THAT DUMP BY GEOFF HARRISON.

; DEFAULT LOCATION IS AT 0FE00H.  MAY BE ASSEMBLED TO RUN
; AT ANY LOCATION.
;
; ASSEMBLER SYNTAX IS FOR THE SPASM ASSEMBLER.  TO ASSEMBLE USE:
;      SPASM MBL /F
;      SLINK MBL=MBL.OBJ /C:0FE00
;
; FOR OTHER ASSEMBLERS, UNCOMMENT THE FOLLOWING LINE AND
; (POSSIBLY) CHANGE THE SYNTAX OF ORG, DB, ETC.
;
                ORG 0FE00H

;----------------------------------------------------------
; WE DON'T KNOW WHAT I/O CARDS ARE IN THE SYSTEM, SO
; TRY TO INITIALIZE JUST ABOUT ANYTHING MITS HAD AVAILABLE
; AT THE TIME.
;
                DI
                XRA A
                OUT 020H
                OUT 021H
                OUT 024H
                OUT 025H
                OUT 026H
                OUT 022H
                CMA
                OUT 023H
                OUT 027H
                MVI A,00CH
                OUT 024H
                MVI A,02CH
                OUT 020H
                OUT 022H
                OUT 026H
                MVI A,003H
                OUT 027H
                OUT 010H
                MVI A,011H
                OUT 010H

;----------------------------------------------------------
; FIND TOP OF RAM.  ASSUMES THAT THERE IS NOT 64K OF RAM
; AVAILABLE, A REASONABLE ASSUMPTION GIVEN THAT THIS ROUTINE
; RESIDES IN ROM SOMEWHERE AT THE TOP OF MEMORY.
;
                LXI H, 0FFFFH
SCANRAM:        INX H           ; POINT @ NEXT BYTE
                MOV A,M         ; GET IT
                MOV B,A         ; SAVE IT
                CMA             ; INVERT IT
                MOV M,A         ; TRY TO WRITE IT BACK OUT
                CMP M           ; SEE IF IT WROTE OUT CORRECTLY
                MOV M,B         ; RESTORE THE BYTE TO ITS ORIG VALUE
                JZ SCANRAM      ; LOOP IF THE BYTE WROTE CORRECTLY

                ; SOMETHING'S WRONG IF THE FAILURE TO WRITE TO RAM
                ; HAPPENED ON OTHER THAN A PAGE BOUNDARY
                XRA A           ; A = 0
                CMP L
                JNZ MERROR      ; IF L != 0 GO TO 'M' ERROR HANDLER

                ; HL NOW POINTS TO THE LAST WRITABLE BYTE IN RAM PLUS 1.
                ; SUBTRACT 14 TO MAKE ROOM FOR A STACK & INITIALIZE SP.
                LXI B,0FFF2H
                DAD B           ; HL += BC
                SPHL            ; SP = HL

                DAD B           ; SET HL TO POINT TO WHAT WILL BE
                                ; THE START OF THE READBYTE ROUTINE.
                PUSH H          ; SAVE THE START ADDRESS ON THE STACK.

                IN 0FFH         ; READ FRONT PANEL SWITCHES
                ANI 00FH        ; MASK LOWER 4 BITS
                CPI 007H        ; SWITCHES SET TO >= 7?
                JP IERROR       ; Y - GO TO 'I' ERROR HANDLER

                ; POINT HL AT THE NTH ENTRY IN THE MOD TABLE,
                ; WHERE N = THE FRONT PANEL SWITCH SETTING
                LXI H, TABLE1   ; POINT HL TO START OF THE MOD TABLE
                INR B           ; B CURRENTLY CONTAINS 0FFH, INC IT TO 0
                MOV C,A         ; \
                ADD A           ;  \ C = A * 3
                ADD C           ;  /
                MOV C,A         ; /
                DAD B           ; HL += BC

;----------------------------------------------------------
; CONSTRUCT AN INPUT FUNCTION ON THE STACK.
; SINCE THIS IS A PUSH DOWN STACK, THE ROUTINE IS BUILT IN REVERSE.
; WHEN FINISHED, THE ROUTINE WILL LOOK LIKE THIS. (XX VALUES ARE
; CALCULATED ON THE FLY OR READ FROM THE MOD TABLE.  THE ROUTINE
; HAS TO BE BUILT DYNAMICALLY LIKE THIS BECAUSE DIFFERENT I/O CARDS
; REQUIRE DIFFERENT CODE TO READ THEIR DATA AND STATUS.  THE USER
; SPECIFIED WHICH CARD IS IN USE ON THE FRONT PANEL SWITCHES.)
; READBYTE:
;       DB XX           IN XX           ; CHECK PORT STATUS
;       E6 XX           ANI XX
;       XX LO HI        JZ/JNZ READBYTE ; LOOP 'TILL BYTE ARRIVES
;       DB XX           IN XX           ; GET INPUT BYTE
;       F5              PUSH PSW        ; SAVE IT
;       80              ADD B           ; UPDATE CHECKSUM IN B
;       47              MOV B,A
;       F1              POP PSW         ; RETRIEVE INPUT BYTE
;       C9              RET             ; RETURN A=BYTE, B=CHECKSUM
;
                POP D           ; DE = THE START ADRESS OF THIS ROUTINE

                ; CONSTRUCT RET; POP PSW
                LXI B,0C9F1H
                PUSH B

                ; CONSTRUCT MOV B,A; ADD B
                LXI B,04780H
                PUSH B

                ; CONSTRUCT  PUSH PSW; {INPUT PORT RETRIEVED FROM MOD TABLE}
                MVI B,0F5H
                MOV C,M
                MOV A,C
                PUSH B

                ; CONSTRUCT IN (USED WITH PORT CONSTRUCTED ABOVE); {HIGH BYTE OF JMP INSTR}
                MVI B,0DBH
                MOV C,D
                PUSH B

                ; CONSTRUCT {LOW BYTE OF JMP}; JZ/JNZ (FROM MOD TABLE)
                MOV B,E
                INX H
                MOV C,M
                PUSH B

                ; CONSTRUCT ANI {MASK FROM MOD TABLE}
                INX H
                MOV B,M
                MVI C,0E6H
                PUSH B

                ; CONSTRUCT IN {PORT STATUS ADDRESS (PORT NUMBER - 1)}
                DCR A
                MOV B,A
                MVI C,0DBH
                PUSH B
;----------------------------------------------------------
; READ A STREAM OF INPUT BYTES.
;
                XCHG            ; HL = START OF READBYTE ROUTINE, DE = JUNK

                ; ???????????????????????????????????????????????????
                MVI A,004H      ; WHY ARE WE SENDING 04H TO DEVICE 027H?
                OUT 027H        ; IN FACT, WHAT IS DEVICE 027H? ANYONE KNOW? IS IT THE
                                ; 88-HSR?  PERHAPS WE'RE SWITCHING ON THE DRIVE MOTOR.
                ; ???????????????????????????????????????????????????

                ; SKIP OVER LEADIN BYTES.
                CALL LINK       ; FLUSH INPUT BUFFER
                CALL LINK       ; GET A BYTE
                MOV C,A         ; REMEMBER IT
LEADINSKIP:     CALL LINK       ; GET ANOTHER BYTE
                CMP C
                JZ LEADINSKIP   ; LOOP UNTIL WE RECEIVE A DIFFERENT BYTE VALUE

                ; AT THIS POINT, C CONTAINS THE FIRST LEADIN BYTE
                ; THAT WAS ON THE TAPE, WHICH SHOULD REPRESENT THE
                ; LENGTH OF THE STAGE 2 LOADER.
                ; SKIP OVER STAGE 2 LOADER.
                DCR C
STAGE2SKIP:     CALL LINK       ; GET A BYTE
                DCR C
                JNZ STAGE2SKIP  ; LOOP WHILE C > 0

                ; NOW WE'VE SKIPPED OVER ALL THE UNNEEDED STUFF, START
                ; LOOKING FOR THE FIRST LOAD RECORD.
FINDTOKEN:      CALL LINK       ; GET A BYTE
                CPI 03CH        ; IS IT A LOAD RECORD TOKEN?
                JZ LOADRECORD   ; Y - GO AND PROCESS A LOAD RECORD
                CPI 078H        ; IS IT AN EOF TOKEN?
                JNZ FINDTOKEN   ; N - KEEP LOOKING

                ; GOT AN EOF TOKEN.  READ NEXT TWO BYTES AS PROGRAM
                ; START ADDRESS AND JUMP TO THAT ADDRESS.
EOF:            CALL LINK       ; GET PROG START LOW
                MOV C,A
                CALL LINK       ; GET PROG START HIGH
                MOV L,C
                MOV H,A

                ; THIS IS MOSTLY USED TO CALL THE BYTE INPUT ROUTINE
                ; ON THE STACK, BUT IS ALSO USED TO JUMP TO THE ENTRY
                ; POINT OF THE DOWNLOADED PROGRAM.
LINK:           PCHL            ; JMP TO (HL)

                ; PROCESS A LOAD RECORD
LOADRECORD:     CALL LINK       ; GET BYTE COUNT IN THIS RECORD
                MOV C,A         ; SAVE IT
                MVI B,000H      ; INITIALIZE CHECKSUM
                CALL LINK       ; GET LOAD ADDRESS LOW
                MOV E,A
                CALL LINK       ; GET LOAD ADDRESS HIGH
                MOV D,A

LOREC2:         MOV A,D
                CMP H           ; ARE THE INCOMING BYTES ABOUT TO
                                ;    OVERWRITE THE READBYTE ROUTINE?
                MVI A,04FH      ; PREPARE TO SEND 'O', IF NECESSARY
                JZ ERREXIT      ; Y - ERROR EXIT
                CALL LINK       ; N - GET ANOTHER BYTE
                XCHG            ; HL = DEST POINTER, DE = START OF READBYTE
                MOV M,A         ; STORE RECEIVED BYTE AT DESTINATION
                CMP M           ; DID IT STORE CORRECTLY?
MERROR:         MVI A,04DH      ; PREPARE TO SEND 'M', IF NECESSARY
                JNZ ERREXIT     ; N - ERROR EXIT
                INX H           ; Y - INCREMENT DESTINATION POINTER
                XCHG            ; HL = START OF READBYTE, DE = DEST POINTER
                DCR C           ; DECREMENT BYTE COUNTER
                JNZ LOREC2      ; IF NOT 0 THEN LOOP TO GET MORE BYTES

                MOV C,B         ; SAVE CALCULATED CHECKSUM VALUE BEFORE WE UPDATE IT AGAIN
                CALL LINK       ; GET EXPECTED CHECKSUM FROM INPUT STREAM
                CMP C           ; DOES IT MATCH OUR CALCULATED SUM?
                JZ FINDTOKEN    ; Y - LOOK FOR MORE RECORDS ON THE TAPE
                MVI A,043H      ; N - PREPARE TO SEND 'C' ERROR
                DB 001H         ; LXI - HIDES NEXT TWO BYTES
IERROR:         DB 03EH         ; MVI A, 049H   ; PREPARE TO SEND 'I'
                DB 049H

; STORE AN ERROR CODE AND THE ADDRESS @ WHICH IT HAPPENED IN
; THE FIRST 3 BYTES OF RAM, THEN LOOP FOREVER SENDING THE
; ERROR CODE TO ALL POSSIBLE TERMINAL DEVICES.
;
ERREXIT:        STA 00000H
                SHLD 00001H
                EI
FOREVER:        OUT 001H
                OUT 011H
                OUT 005H
                OUT 023H
                JMP FOREVER

;----------------------------------------------------------
; MOD TABLE.
; THIS IS A TABLE OF PORT ADDRESSES, COMMANDS FOR CHECKING
; THE PORT STATUS (JZ/JNZ), AND STATUS MASKS FOR SEVERAL
; I/O BOARDS.  THE VALUES ARE STUFFED INTO THE READBYTE
; ROUTINE AT RUNTIME TO CUSTOMIZE IT FOR THE HARDWARE
; BEING USED TO LOAD THE TAPE.
;
TABLE1:         DB      011H, 0CAH, 001H        ; 2SIO (2 STOP BITS)
                DB      011H, 0CAH, 001H        ; 2SIO (1 STOP BIT)
                DB      001H, 0C2H, 001H        ; SIO
                DB      007H, 0C2H, 001H        ; ACR
                DB      021H, 0CAH, 080H        ; 4PIO
                DB      005H, 0CAH, 002H        ; PIO
                DB      025H, 0CAH, 040H        ; HSR

                END
