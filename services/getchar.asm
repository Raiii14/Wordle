
.MODEL SMALL

EXTRN IsValidWord:NEAR

.DATA

; buffered input for up to 5 characters + carriage return
input1 DB 05, ?, 06 DUP(?)

; error message shown when user enters a word not in the list
errInvalid DB 'Not in word list',0Dh,0Ah,'$'

; center column per box (text grid cols), for 5 boxes left -> right
; computed from START_X=169, BOX_WIDTH=54, BOX_GAP=10
; result: 24, 32, 40, 48, 56 (increments by 8)
colTable DB 24, 32, 40, 48, 56
; active text-row to echo into (top of 8x16 cell). 4 = first row center, 8 = second row center, etc.
RowCenter DB 4


.CODE

; -------------------------------------------------------
; flow summary (current build)
; - si points to the input buffer; bl holds current length (0..5)
; - loop:
;   - read a key (INT 16h)
;   - if Enter:
;       - if bl == 5 
;           if is valid -> accept finalize buffer (DOS 0Ah layout), print CR/LF, return
;           else ->show error, stay in row
;       - else → keep waiting for more input
;   - else if Backspace and bl > 0:
;       - decrement bl and si; move cursor to row 4 and center column for that index
;       - print the removed character in black to visually erase it
;   - else if key is a letter:
;       - convert lowercase to uppercase; if bl < 5 store it (buffer[si] = AL)
;       - increment bl; move cursor to row 4 and center column for (bl-1)
;       - print the character in bright white
;   - else:
;       - ignore the key and read again
; -------------------------------------------------------

; blocks until exactly 5 characters are entered; retains what was typed if enter is pressed early
; returns:
;   AL = length (always 5 on return)
;   CX = length (5)
;   SI = the pointer to first character (input1+2)


PUBLIC GetExactly5
GetExactly5 PROC NEAR
	LEA SI, input1+2     ; si -> first character position in the buffer
	XOR BX, BX         ; bl = length (0..5)

    ; Similar to = while(true)
    ReadLoop:
        ; wait for a keystroke (blocking)
        MOV AH, 00h         ; ah=00h read key
        INT 16h            ; al=ascii (if any), ah=scancode

        ; ================================================================

        ; Exit early if Escape is pressed
        CMP AL, 1Bh        ; ESC?
        JE  OnEscape

        ; ================================================================

        ; - if(KeyPressed == Enter && i == 5)
        ; - Which means that there are already 5 characters entered

        CMP AL, 0Dh        ; enter?
        JE  OnEnter        ; to prevent jump out of range (limit of +-127), make a function that JMPs to the real function
        JMP AfterEnterCheck

    OnEnter:
        JMP OnEnter_real   ; near jump to real handler (fixes out-of-range)

    ; Handle Escape: signal abort (AL=0, CX=0) and return
    OnEscape:
        XOR AX, AX         ; AL=0 (length), AH=0
        XOR CX, CX         ; CX=0 length
        LEA SI, input1+2   ; SI still points to buffer start (not used by caller)
        RET

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
        ; The push and pop in the stacks are used because we don't want to overwrite what's stored in those registers
        ; So we save those values first, then use the registers for setting the values we need, then restore the previous values
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        PUSH SI
        PUSH DI
        ; =====================================================
        MOV AH, 02h         ; set cursor
        MOV BH, 0           ; page 0
    MOV DH, [RowCenter] ; center row (selectable)
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
        ; ======================================================
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
        ; accept letters only, and converts lowercase to uppercase
        ; if AL in 'A'..'Z' keep it. if in 'a'..'z' convert to upper case. else ignore
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
            ; stores the character in the buffer (like putting a character in an array position)
            MOV [SI], AL
            INC SI
            INC BL
        
    ; echo the character centered in its box using the table
    ; so we save and restore registers to the stack, to avoid overwriting values
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    ; =====================================================
    ; idx = BL-1 (0..4)
    MOV CL, BL
    DEC CL
    MOV DI, OFFSET colTable
    XOR CH, CH
    ADD DI, CX
    MOV DL, [DI]       ; DL = center col for this box
    MOV DH, [RowCenter]     ; active center row
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
    ; =====================================================
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
        JE  HaveFiveChars       ; 
        JMP ReadLoop       ; not enough characters, keep buffer and go back to the starting loop

    HaveFiveChars:
        ; validate word before accepting
        LEA SI, input1+2
        CALL IsValidWord
        CMP AL, 0;
        JE InvalidWord ; jump if word is not in the pool of words

        ; finalize buffer per DOS 0Ah layout for compatibility
        MOV [input1+1], BL       ; actual length
        MOV BYTE PTR [input1+2+5], 0Dh   ; terminating CR
        
        MOV AL, BL
        XOR AH, AH
        MOV CX, AX             ; cx = 5
        LEA SI, input1+2         ; si -> first character
        RET
        
    InvalidWord:
        ; Show a short error message and continue accepting input
        PUSH AX
        LEA DX, errInvalid
        MOV AH, 09h
        INT 21h
        POP AX
        JMP ReadLoop
GetExactly5 ENDP

; -------------------------------------------------------
; SetEchoRow
; - sets which text-row (DH) the echo/erase uses
; - usage: AL = row index (e.g., 4 for first row center, 7 for second row center)
; - example: SetEchoRow(7) in Java style
; -------------------------------------------------------
PUBLIC SetEchoRow
SetEchoRow PROC NEAR
    MOV [RowCenter], AL
    RET
SetEchoRow ENDP

END