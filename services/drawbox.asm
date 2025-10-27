; draws a row of 5 boxes in mode 12h (640x480x16)
; 8.3 filename alias for dos/tasm convenience

.MODEL SMALL

; instead of using .DATA, we used fixed constants, like in Java which is 'final'
; box settings
BOX_WIDTH  EQU 54       ; Box width equals 54, immediate address
BOX_HEIGHT EQU 52
BOX_GAP    EQU 10
START_X    EQU 169
START_Y    EQU 46
BOX_COLOR  EQU 0Fh      ; white/high-intensity, to change the intensity, change the 4 bits, instead of 2 bits only

; vertical spacing between rows
ROW_GAP    EQU 10

; small data to support drawing multiple rows cleanly
.DATA
YBASE      DW 0         ; current row's top Y (in pixels)
ROWS_LEFT  DB 0         ; how many rows to draw (we'll set to 2)

; -------------------------------------------------------
; flow summary (current build)
; - called after main switches to VGA mode 12h
; - draw 2 rows total; for each row:
;   - set YBASE to row's top (first row = START_Y; second row = START_Y + BOX_HEIGHT + ROW_GAP)
;   - repeat 5 times (i = 0..4):
;   - compute right (DI) and bottom (BP) edges from START_X/START_Y and BOX_WIDTH/BOX_HEIGHT
;   - draw top line (left → right)
;   - draw bottom line (left → right)
;   - draw left line (top → bottom)
;   - draw right line (top → bottom)
;   - move to next box by adding (BOX_WIDTH + BOX_GAP) to SI (x position)
; - return to caller
; -------------------------------------------------------

.CODE
PUBLIC DrawBoxes
DrawBoxes PROC NEAR

        ; draw exactly 2 rows (simple scaler without duplicating code)
        MOV BYTE PTR [ROWS_LEFT], 6

ROW_START:
        ; set YBASE depending on which row we're on
        MOV AL, [ROWS_LEFT]
        CMP AL, 2
        JNE SECOND_ROW
FIRST_ROW:
        MOV AX, START_Y
        MOV [YBASE], AX
        JMP ROW_SETUP_DONE
SECOND_ROW:
        MOV AX, START_Y
        ADD AX, BOX_HEIGHT
        ADD AX, ROW_GAP
        MOV [YBASE], AX
ROW_SETUP_DONE:

        MOV AH, 0Ch
        MOV AL, BOX_COLOR
        MOV BH, 0

        MOV BX, 5                 ; 5 boxes per row
        MOV SI, START_X           ; start X for the row
        ; DI will be loaded from YBASE per box below

    ; The starting loop for drawing the boxes, like the for loop
    ; for (int i = 0; i < 5; i++) - which means this will print a box 5 times
    OUTER_BOX_LOOP:
        MOV DI, [YBASE]           ; top Y for this row

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

        MOV DX, [YBASE]
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
        MOV DX, [YBASE]

    ; draws the left line, from top to bottom
    LEFT_LINE_LOOP:
        CMP DX, BP
        JAE END_LEFT_LINE
        INT 10h
        INC DX
        JMP LEFT_LINE_LOOP
    END_LEFT_LINE:
        MOV CX, DI
        MOV DX, [YBASE]

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

    ; one row finished; if another row remains, set up and draw it
    ; trampoline pattern: short JZ to skip, near JMP back to ROW_START
    DEC BYTE PTR [ROWS_LEFT]
    JZ  DoneRows       ; if zero rows left, skip the jump-back
    JMP ROW_START      ; else, near jump back (no range limit)

DoneRows:
    RET
DrawBoxes ENDP

END
