; word comparison
; determine the correctness

.MODEL SMALL

.DATA
    ; TODO: Add target word, guess buffer, etc.

.CODE
PUBLIC CompareWords
PUBLIC IsWordCorrect

; compares user guess to the target word
CompareWords PROC NEAR
    ;implementation
    RET
CompareWords ENDP



;check if correct
; turn al = 1 if correct
IsWordCorrect PROC NEAR
    ;implementation
    MOV AL, 0    ; Default: not correct
    RET
IsWordCorrect ENDP

END