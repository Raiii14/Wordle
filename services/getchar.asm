.MODEL SMALL

.DATA

; buffered input for up to 5 characters + carriage return
word DB 05, ?, 06 DUP(?)

.CODE
PUBLIC GetInput
GetInput PROC NEAR
	; expects: DS already set by caller
	; returns:
	;   AL = length typed (0..5)
	;   CX = length typed (0..5)
	;   SI = pointer to first character (word+2)
	;   buffer layout: [word+0]=max, [word+1]=len, [word+2..]=chars, [word+2+len]=0Dh

	LEA DX, word       ; dx -> input buffer
	MOV AH, 0Ah        ; DOS buffered input
	INT 21h

	MOV AL, [word+1]   ; al = length typed
	XOR AH, AH         ; ax = length
	MOV CX, AX         ; cx = length
	LEA SI, word+2     ; si -> first character

	RET
GetInput ENDP

; blocks until exactly 5 characters are entered; retains what was typed if enter is pressed early
; returns:
;   AL = length (always 5 on return)
;   CX = length (5)
;   SI = the pointer to first character (word+2)

PUBLIC GetExactly5
GetExactly5 PROC NEAR
	LEA SI, word+2     ; si -> first character position
	XOR BX, BX         ; bl = length (0..5)

    ReadLoop:
        ; wait for a keystroke (blocking)
        XOR AH, AH         ; ah=00h read key
        INT 16h            ; al=ascii (if any), ah=scancode

        CMP AL, 0Dh        ; enter?
        JE  OnEnter

        CMP AL, 08h        ; backspace?
        JNE NotBackspace

        CMP BL, 0
        JE  ReadLoop       ; nothing to delete

        ; update buffer (remove last char)
        DEC BL
        DEC SI
        ; visually erase last echoed char: BS, space, BS
        PUSH AX
        PUSH BX

        MOV AH, 0Eh        ; teletype output
        MOV BH, 0          ; page 0
        MOV BL, 0Fh        ; color (bright white)
        MOV AL, 08h        ; backspace
        INT 10h

        MOV AL, 20h        ; space
        INT 10h
        MOV AL, 08h        ; backspace
        INT 10h
        POP BX
        POP AX
        JMP ReadLoop

    ; The label for actually storing each character
    NotBackspace:
        CMP BL, 5
        JAE ReadLoop       ; already at max, ignore extra chars
        ; store character
        MOV [SI], AL
        INC SI
        INC BL
        ; echo character using BIOS teletype (works in graphics mode)
        PUSH AX
        PUSH BX
        MOV AH, 0Eh        ; teletype output
        MOV BH, 0          ; page 0
        MOV BL, 0Fh        ; bright white
        INT 10h            ; prints AL in current mode
        POP BX             ; restore BL=length and BH
        POP AX
        JMP ReadLoop

    OnEnter:
        CMP BL, 5
        JNE ReadLoop       ; not enough, keep buffer and continue reading

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