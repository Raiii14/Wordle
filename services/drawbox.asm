; draws a row of 5 boxes in mode 12h (640x480x16)
; 8.3 filename alias for dos/tasm convenience

.MODEL SMALL

; instead of using .DATA, we used fixed constants, like in Java which is 'final'
; box settings
BOX_WIDTH  EQU 75       ; Box width equals 75, immediate address
BOX_HEIGHT EQU 70
BOX_GAP    EQU 15
START_X    EQU 100
START_Y    EQU 65
BOX_COLOR  EQU 0Eh      ; yellow/high-intensity

.CODE
PUBLIC DrawBoxes
DrawBoxes PROC NEAR

        MOV AH, 0Ch
        MOV AL, BOX_COLOR
        MOV BH, 0

        MOV BX, 5
        MOV SI, START_X
        MOV DI, START_Y

    OUTER_BOX_LOOP:
        MOV DI, START_Y

        PUSH BX

        MOV CX, SI
        ADD CX, BOX_WIDTH

        MOV DX, DI
        ADD DX, BOX_HEIGHT

        MOV DI, CX
        MOV BP, DX

        MOV AH, 0Ch
        MOV AL, BOX_COLOR
        MOV BH, 0

        MOV DX, START_Y
        MOV CX, SI
    TOP_LINE_LOOP:
        CMP CX, DI
        JAE END_TOP_LINE
        INT 10h
        INC CX
        JMP TOP_LINE_LOOP
    END_TOP_LINE:

        MOV DX, BP
        MOV CX, SI
    BOTTOM_LINE_LOOP:
        CMP CX, DI
        JAE END_BOTTOM_LINE
        INT 10h
        INC CX
        JMP BOTTOM_LINE_LOOP
    END_BOTTOM_LINE:

        MOV CX, SI
        MOV DX, START_Y
    LEFT_LINE_LOOP:
        CMP DX, BP
        JAE END_LEFT_LINE
        INT 10h
        INC DX
        JMP LEFT_LINE_LOOP
    END_LEFT_LINE:

        MOV CX, DI
        MOV DX, START_Y
    RIGHT_LINE_LOOP:
        CMP DX, BP
        JAE END_RIGHT_LINE
        INT 10h
        INC DX
        JMP RIGHT_LINE_LOOP
    END_RIGHT_LINE:

        ADD SI, BOX_WIDTH
        ADD SI, BOX_GAP

        POP BX
        DEC BX
        JNE OUTER_BOX_LOOP

        RET
DrawBoxes ENDP

END
