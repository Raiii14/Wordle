; Color result mapping
; Transforms comparison results into color codes

.MODEL SMALL

.DATA
    colorResults DB 5 DUP(0)    ; 0=gray, 1=yellow, 2=green

.CODE
PUBLIC GetColorResults

GetColorResults PROC NEAR
    ; implementation
    LEA SI, colorResults
    RET
GetColorResults ENDP

END