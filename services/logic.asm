.MODEL SMALL

.DATA
; target word (5 letters, uppercase)
targetWord DB 'CRANE'

; colors: 0 = gray/miss, 1 = yellow (present), 2 = green (correct position)
colorResults DB 5 DUP(0)

; simple status messages
msg_win DB 'You win!',0Dh,0Ah,'$'
msg_lose DB 'Out of lives. Game over.',0Dh,0Ah,'$'

.CODE

; external input routine (reads exactly 5 letters and returns SI->buffer, CX=length)
EXTRN GetExactly5:NEAR

; expose functions expected by mainModu/wordle.asm
PUBLIC GameLogic
PUBLIC CompareWords
PUBLIC GetColorResults
PUBLIC IsWordCorrect

; ----------------------------
; GetRandomWord
; for now, returns a fixed target word in `targetWord`
GetRandomWord PROC NEAR
    ; targetWord already initialized in DATA but we keep this proc so caller can refresh or randomize later
    RET
GetRandomWord ENDP

; ----------------------------
; CompareGuess
; Inputs: SI -> guess buffer (5 bytes), DS points to data segment containing targetWord
; Outputs: fills colorResults (0..2) bytes
CompareGuess PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DI
    PUSH SI

    ; BX = base of targetWord, SI = base of guess buffer (unchanged)
    LEA BX, targetWord

    XOR DI, DI        ; index i = 0
CmpLoop:
    MOV AL, [SI]      ; guess char (SI points to guess buffer)
    MOV DL, [BX+DI]   ; target char
    CMP AL, DL
    JE  SetGreen

    ; not same position -> scan target for presence
    PUSH DI           ; save current position index
    XOR DI, DI        ; j = 0 (use DI for scan)
ScanLoop:
    MOV DL, [BX+DI]
    CMP AL, DL
    JE  FoundPresent
    INC DI
    CMP DI, 5
    JB  ScanLoop
    ; not found
    POP DI            ; restore position index
    MOV BYTE PTR [colorResults+DI], 0
    JMP AfterSet

FoundPresent:
    POP DI            ; restore position index
    MOV BYTE PTR [colorResults+DI], 1
    JMP AfterSet

SetGreen:
    MOV BYTE PTR [colorResults+DI], 2

AfterSet:
    INC SI
    INC DI
    CMP DI, 5
    JB CmpLoop

    POP SI
    POP DI
    POP CX
    POP BX
    POP AX
    RET
CompareGuess ENDP

    ; Wrapper to match original project API
    ; CompareWords : expects SI pointing to guess buffer (GetExactly5 returns SI)
    CompareWords PROC NEAR
        ; simply call internal CompareGuess which uses SI
        CALL CompareGuess
        RET
    CompareWords ENDP

; ----------------------------
; DisplayColors
; prints a simple textual representation of the color results using teletype (AH=0Eh)
DisplayColors PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI

    MOV CX, 5
    XOR DI, DI
DispLoop:
    MOV AL, [colorResults+DI]
    CMP AL, 2
    JE  PrintG
    CMP AL, 1
    JE  PrintY
    ; else print '-'
    MOV AL, '-'
    JMP DoPrint
PrintY:
    MOV AL, 'Y'
    JMP DoPrint
PrintG:
    MOV AL, 'G'
DoPrint:
    MOV AH, 0Eh
    MOV BH, 0
    INT 10h
    INC DI
    LOOP DispLoop

    ; print CR LF for next line
    MOV AH, 0Eh
    MOV AL, 0Dh
    INT 10h
    MOV AL, 0Ah
    INT 10h

    POP DI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
DisplayColors ENDP

; return pointer to colorResults in SI (like previous GetColorResults stub expected)
GetColorResults PROC NEAR
    LEA SI, colorResults
    RET
GetColorResults ENDP

; IsWordCorrect: returns AL=1 if all entries == 2 (green)
IsWordCorrect PROC NEAR
    PUSH CX
    PUSH DI
    XOR DI, DI
    MOV CX, 5
CheckLoop:
    MOV AL, [colorResults+DI]
    CMP AL, 2
    JE NextOK
    MOV AL, 0
    POP DI
    POP CX
    RET
NextOK:
    INC DI
    LOOP CheckLoop
    MOV AL, 1
    POP DI
    POP CX
    RET
IsWordCorrect ENDP

; ----------------------------
; ClearColorResults
ClearColorResults PROC NEAR
    MOV CX, 5
    XOR DI, DI
ClrLoop:
    MOV BYTE PTR [colorResults+DI], 0
    INC DI
    LOOP ClrLoop
    RET
ClearColorResults ENDP

; ----------------------------
; GameLogic
; Main loop: pick word, read guesses, compare, display, track lives
GameLogic PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ; lives = 6 (use BL)
    MOV BL, 6

    ; pick a word
    CALL GetRandomWord

MainLoop:
    ; call input routine; returns SI->5-chars, CX=5
    CALL GetExactly5

    ; SI points to guess buffer
    CALL CompareGuess

    ; show results
    CALL DisplayColors

    ; check if all green
    MOV CX, 5
    XOR SI, SI
    MOV AL, 1
    ; assume guessed, clear AL-> will use AL as flag; set AL=1 then AND with (color==2)
    MOV AL, 1
    MOV DL, 1
    XOR AH, AH
    ; we will test each, if any !=2 -> not guessed
    XOR DI, DI
    MOV CX, 5
CheckAllGreen:
    MOV AL, [colorResults+DI]
    CMP AL, 2
    JE NextIdx
    ; not green
    MOV AH, 0
    JMP NotAllGreen
NextIdx:
    INC DI
    LOOP CheckAllGreen
    ; if we got here all were green
    MOV AH, 1
NotAllGreen:
    CMP AH, 1
    JE Win

    ; not won yet: decrement lives and continue if lives remain
    DEC BL
    CMP BL, 0
    JG ContinuePlay

    ; out of lives -> lose
    ; print lose message via DOS AH=09
    MOV DX, OFFSET msg_lose
    MOV AH, 09h
    INT 21h
    JMP GL_End

ContinuePlay:
    ; reset color results and continue
    CALL ClearColorResults
    JMP MainLoop

Win:
    MOV DX, OFFSET msg_win
    MOV AH, 09h
    INT 21h

GL_End:
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
GameLogic ENDP

END
