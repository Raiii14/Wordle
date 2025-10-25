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
BOX_COLOR  EQU 0Eh      ; yellow/high-intensity, to change the intensity, change the 4 bits, instead of 2 bits only

.CODE
PUBLIC DrawBoxes
DrawBoxes PROC NEAR

        MOV AH, 0Ch
        MOV AL, BOX_COLOR
        MOV BH, 0

        MOV BX, 5
        MOV SI, START_X
        MOV DI, START_Y

    ; The starting loop for drawing the boxes, like the for loop
    ; for (int i = 0; i > 5; i++) - which means this will print a box 5 times
    OUTER_BOX_LOOP:
        MOV DI, START_Y

        PUSH BX

        ; sets the size and color of the box
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
    
    ; draws the top line of a box, from left to right
    TOP_LINE_LOOP:
        CMP CX, DI
        JAE END_TOP_LINE
        INT 10h
        INC CX
        JMP TOP_LINE_LOOP
    END_TOP_LINE:
        MOV DX, BP
        MOV CX, SI

    ; draws the bottom line, from left to right
    BOTTOM_LINE_LOOP:
        CMP CX, DI
        JAE END_BOTTOM_LINE
        INT 10h
        INC CX
        JMP BOTTOM_LINE_LOOP
    END_BOTTOM_LINE:
        MOV CX, SI
        MOV DX, START_Y

    ; draws the left line, from top to bottom
    LEFT_LINE_LOOP:
        CMP DX, BP
        JAE END_LEFT_LINE
        INT 10h
        INC DX
        JMP LEFT_LINE_LOOP
    END_LEFT_LINE:
        MOV CX, DI
        MOV DX, START_Y

    ; draws the right line, from top to bottom
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
