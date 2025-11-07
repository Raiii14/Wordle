; validation service (check if the input word is in the pool of words)

.MODEL SMALL 

.DATA
; Simple word list for testing - add more words as needed
WordList DB "HELLO"
         DB "WORLD"
         DB "APPLE"
         DB "GRAPE"
         DB "SWORD"
         DB "PLANT"
         DB "LIGHT"
         DB "STACK"
         DB "FRAME"
         DB "CRANE"
WordCount EQU 10

.CODE
PUBLIC IsValidWord

; Check if the 5 letter word is in the word list
; Input: SI = pointer to 5 char word
; Output: AL = 1 if valid, 0 if invalid
    
IsValidWord PROC NEAR 
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    
    ; Start by assuming invalid
    MOV AL, 0               ; AL = 0 (invalid) by default
    
    ; Loop through word list
    MOV CX, WordCount       ; number of words to check
    LEA DI, WordList        ; DI points to first word
    
CheckNextWord:
    PUSH SI                 ; save input pointer
    PUSH DI                 ; save wordlist pointer
    MOV BX, 5               ; compare 5 characters
    
CompareChars:
    MOV DL, [SI]            ; get input char
    CMP DL, [DI]            ; compare with wordlist char
    JNE NotThisWord         ; if different, try next word
    INC SI                  ; next input char
    INC DI                  ; next wordlist char
    DEC BX                  ; decrement counter
    JNZ CompareChars        ; continue if more chars to check
    
    ; All 5 characters matched!
    POP DI
    POP SI
    MOV AL, 1               ; valid word
    JMP Done
    
NotThisWord:
    POP DI
    POP SI
    ADD DI, 5               ; move to next word in list (5 bytes per word)
    LOOP CheckNextWord      ; check next word (decrements CX)
    
    ; If we get here, no match was found
    ; AL is already 0 from initialization
    
Done:
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    RET

IsValidWord ENDP

END