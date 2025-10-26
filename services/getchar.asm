.MODEL SMALL

.DATA

; buffered input for up to 5 characters + carriage return
word DB 05, ?, 06 DUP(?)


.CODE

; blocks until exactly 5 characters are entered; retains what was typed if enter is pressed early
; returns:
;   AL = length (always 5 on return)
;   CX = length (5)
;   SI = the pointer to first character (word+2)


PUBLIC GetExactly5
GetExactly5 PROC NEAR
	LEA SI, word+2     ; si -> first character position
	XOR BX, BX         ; bl = length (0..5)

    ; set starting cursor for graphics teletype to pixel (115,80)
    ; col = 115/8 = 14, row = 80/16 = 5
    PUSH AX
    PUSH BX
    PUSH DX
    MOV AH, 02h
    MOV BH, 0          ; video page 0
    MOV DH, 6          ; row
    MOV DL, 17         ; col
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
        ; visually erase last echoed char: BS, space, BS (teletype)
        PUSH AX
        PUSH BX
        MOV AH, 0Eh         ; teletype output
        MOV BH, 0           ; page 0
        MOV BL, 0Fh         ; bright white
        MOV AL, 08h         ; backspace
        INT 10h
        MOV AL, 20h         ; space
        INT 10h
        MOV AL, 08h         ; backspace
        INT 10h
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
    ; echo character using BIOS teletype (continue from current cursor)
    PUSH AX
    PUSH BX
    MOV AH, 0Eh        ; teletype output
    MOV BH, 0          ; page 0
    MOV BL, 0Fh        ; bright white
    MOV AL, [SI-1]
    INT 10h            ; prints AL in current mode
    POP BX             ; restore BL=length and BH
    POP AX
        JMP ReadLoop

    OnEnter_real:
        CMP BL, 5
        JE  HaveFive
        JMP ReadLoop       ; not enough characters, keep buffer and go back to the starting loop

    HaveFive:

        ; finalize buffer per DOS 0Ah layout for compatibility
        MOV [word+1], BL       ; actual length
        MOV BYTE PTR [word+2+5], 0Dh   ; terminating CR

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
        LEA SI, word+2         ; si -> first character
        RET
GetExactly5 ENDP

END