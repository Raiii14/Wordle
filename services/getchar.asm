.MODEL SMALL

.DATA

; buffered input for up to 5 characters + carriage return
input1 DB 05, ?, 06 DUP(?)
; center column per box (text grid cols), for 5 boxes left -> right
; computed from START_X=169, BOX_WIDTH=54, BOX_GAP=10
; result: 24, 32, 40, 48, 56 (increments by 8)
colTable DB 24, 32, 40, 48, 56
ROW_CENTER EQU 4


.CODE

; blocks until exactly 5 characters are entered; retains what was typed if enter is pressed early
; returns:
;   AL = length (always 5 on return)
;   CX = length (5)
;   SI = the pointer to first character (input1+2)


PUBLIC GetExactly5
GetExactly5 PROC NEAR
	LEA SI, input1+2     ; si -> first character position in the buffer
	XOR BX, BX         ; bl = length (0..5)

    ; set starting cursor for graphics teletype to pixel (115,80)
    ; col = 115/8 = 14, row = 80/16 = 5
    PUSH AX
    PUSH BX
    PUSH DX
    MOV AH, 02h
    MOV BH, 0          ; video page 0
    MOV DH, 4          ; row
    MOV DL, 32         ; col
    INT 10h
    POP DX
    POP BX
    POP AX

    ; Similar to = while(true)
    ReadLoop:
        ; wait for a keystroke (blocking)
        MOV AH, 00h         ; ah=00h read key
        INT 16h            ; al=ascii (if any), ah=scancode

        ; ================================================================

        ; - if(KeyPressed == Enter && i == 5)
        ; - Which means that there are already 5 characters entered

        CMP AL, 0Dh        ; enter?
        JE  OnEnter        ; keep format; trampoline right below
        JMP AfterEnterCheck

    OnEnter:
        JMP OnEnter_real   ; near jump to real handler (fixes out-of-range)

    AfterEnterCheck:


        ; - else if(KeyPressed != Backspace)
        ; - This is the function that stores each character in the buffer
        
        CMP AL, 08h         ; backspace?
        JNE NotBackspace


        ; - Checks if the length of the input is at 0
        ; - If equal (JE), goes back to the beginning of the loop
        CMP BL, 0
        JE  ReadLoop        ; nothing to delete

        ; - If not equal, it will erase the last character on the screen
        ; - Think of the instructions below as else {}
        ; ================================================================

        ; update buffer (remove last char)
        DEC BL
        DEC SI
    ; visually erase the removed char at its box center
    ; move cursor to row=4 (center row), col from table by index BL
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    MOV AH, 02h         ; set cursor
    MOV BH, 0           ; page 0
    MOV DH, 4           ; center row (precomputed)
    MOV DI, OFFSET colTable
    XOR CH, CH
    MOV CL, BL          ; index = BL (0..4)
    ADD DI, CX
    MOV DL, [DI]        ; DL = col
    INT 10h
    ; print same removed char in black to overwrite pixels
    MOV AH, 0Eh         ; teletype output
    MOV BH, 0
    PUSH BX             ; save BL=len
    XOR BL, BL          ; BL=0 (black)
    MOV AL, [SI]        ; removed character
    INT 10h
    POP BX
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
        JMP ReadLoop        ; goes back to the beginning of the loop after erasing the last echoed character


    ; The label/loop for actually storing each character
    NotBackspace:
        ; accept letters only; force lowercase to uppercase
        ; if AL in 'A'..'Z' keep; if in 'a'..'z' convert; else ignore
        CMP AL, 'A'
        JB  NotLetter
        CMP AL, 'Z'
        JBE LetterOK
        CMP AL, 'a'
        JB  NotLetter
        CMP AL, 'z'
        JA  NotLetter
        AND AL, 0DFh            ; make uppercase
    LetterOK:
        CMP BL, 5
        JB  DoStore         ; short jump if below max
        JMP ReadLoop        ; already at max, ignore extra chars
    NotLetter:
        JMP ReadLoop        ; ignore non-letters
    DoStore:
        ; store character
        MOV [SI], AL
        INC SI
        INC BL
    ; echo the character centered in its box using the table
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    ; idx = BL-1 (0..4)
    MOV CL, BL
    DEC CL
    MOV DI, OFFSET colTable
    XOR CH, CH
    ADD DI, CX
    MOV DL, [DI]       ; DL = center col for this box
    MOV DH, 4          ; row = 4 (center row)
    MOV AH, 02h        ; set cursor
    MOV BH, 0
    INT 10h
    ; draw the character in bright white
    MOV AH, 0Eh
    MOV BH, 0
    PUSH BX            ; preserve BL=len
    MOV BL, 0Fh
    MOV AL, [SI-1]
    INT 10h
    POP BX
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
        JMP ReadLoop

    OnEnter_real:
        CMP BL, 5
        JE  HaveFive
        JMP ReadLoop       ; not enough characters, keep buffer and go back to the starting loop

    HaveFive:

        ; finalize buffer per DOS 0Ah layout for compatibility
        MOV [input1+1], BL       ; actual length
        MOV BYTE PTR [input1+2+5], 0Dh   ; terminating CR

        ; optionally move to next line for readability
        PUSH AX
        PUSH BX
        MOV AH, 0Eh
        MOV BH, 0
        MOV BL, 0Fh
        MOV AL, 0Dh        ; CR
        INT 10h
        MOV AL, 0Ah        ; LF
        INT 10h
        POP BX
        POP AX

        MOV AL, BL
        XOR AH, AH
        MOV CX, AX             ; cx = 5
        LEA SI, input1+2         ; si -> first character
        RET
GetExactly5 ENDP

END