; validation service ( check if the input word is in the pool of words)

.MODEL SMALL 

.DATA

.CODE
PUBLIC IsValidWord
;  Check if the 5-letter word (pointed by SI) exists in the loaded word list
;  Inputs:
;    SI -> pointer to 5-character buffer (not necessarily zero-terminated)
;  Returns:
;    AL = 1 if word exists in wordList, 0 otherwise

; External symbols from getword.asm
; wordList is a byte array, wordCount is a word (DW)
EXTRN wordList:BYTE
EXTRN wordCount:WORD

IsValidWord PROC NEAR
    ; preserve registers used
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP

    ; save guess pointer
    MOV BP, SI        ; BP = pointer to guessed word (5 bytes)

    ; get number of words
    MOV CX, wordCount
    CMP CX, 0
    JE NotFound       ; no words loaded -> not found

    LEA SI, wordList  ; SI points to first word in list
    ; Use BX as pointer to current word base and SI as guess base
    LEA BX, wordList  ; BX = base of word list

OuterLoop:
    ; SI will be used as guess base pointer (BP holds guess pointer)
    MOV SI, BP        ; SI = guess pointer
    ; DI = pointer to current word start (copy BX)
    MOV DI, BX
    ; DX = letter counter = 5
    MOV DX, 5

CompareLoop:
    MOV AL, [DI]
    MOV AH, [SI]
    CMP AL, AH
    JNE NextWord
    INC DI
    INC SI
    DEC DX
    JNZ CompareLoop
    ; matched all 5 letters
    MOV AL, 1
    JMP ReturnClean

NextWord:
    ADD BX, 5         ; advance BX to next word start
    LOOP OuterLoop    ; CX--, repeat until CX==0

NotFound:
    XOR AL, AL        ; AL = 0

ReturnClean:
    ; restore registers in reverse order
    POP BP
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
IsValidWord ENDP

END