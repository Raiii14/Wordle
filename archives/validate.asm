; validation service (check if the input word is in the pool of words)

.MODEL SMALL 

.DATA
; External word list access
EXTRN wordList:BYTE
EXTRN wordCount:WORD

.CODE
PUBLIC IsValidWord

; IsValidWord
; Check if the 5 letter word exists in the word pool
; Input: SI = pointer to 5 char word buffer
; Output: AL = 1 if valid, 0 if invalid
IsValidWord PROC NEAR 
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP

    ; Get word count
    MOV CX, wordCount
    CMP CX, 0
    JE NotFound         ; No words loaded

    ; Point DI to start of word list
    LEA DI, wordList
    MOV BP, SI          ; Save input pointer in BP

CheckNextWord:
    ; Compare 5 characters
    MOV SI, BP          ; Reset input pointer
    MOV BX, 5           ; 5 characters to compare

CompareLoop:
    MOV AL, [SI]        ; Get input char
    MOV AH, [DI]        ; Get word list char
    
    ; Convert both to uppercase for comparison
    CMP AL, 'a'
    JB InputUpper
    CMP AL, 'z'
    JA InputUpper
    SUB AL, 32
InputUpper:
    CMP AH, 'a'
    JB ListUpper
    CMP AH, 'z'
    JA ListUpper
    SUB AH, 32
ListUpper:
    
    CMP AL, AH
    JNE NoMatch
    
    INC SI
    INC DI
    DEC BX
    JNZ CompareLoop
    
    ; All 5 characters matched!
    JMP Found

NoMatch:
    ; Move DI to next word (skip remaining chars of current word)
    SUB BX, 5           ; BX is negative or 0
    NEG BX              ; BX = chars already compared
    MOV AX, 5
    SUB AX, BX          ; AX = chars remaining
    ADD DI, AX          ; Skip to next word
    
    LOOP CheckNextWord  ; Check next word

NotFound:
    ; Word not found - return 0 (invalid)
    ; Error message will be shown in getchar.asm
    MOV AL, 0           ; Return 0 (invalid)
    JMP ValidateExit

Found:
    MOV AL, 1           ; Return 1 (valid)

ValidateExit:
    POP BP
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    RET
IsValidWord ENDP

END