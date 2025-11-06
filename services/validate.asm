; validation service ( check if the input word is in the pool of words)

.MODEL SMALL 

.DATA

.CODE
PUBLIC IsValidWord
;  check if the 5 letter word is ready
;  input, SI, the pointer of ao 5 char worda
    
IsValidWord PROC NEAR 
    MOV AL, 1
    RET

IsValidWord ENDP

END