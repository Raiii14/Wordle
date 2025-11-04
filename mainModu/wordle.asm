
.MODEL SMALL

.STACK 64

; Constants for Video Modes
MODE_12        EQU 12H    ; 640x480, 16 colors (VGA)
BIOS_VIDEO_INT EQU 10H
DOS_INT        EQU 21H

; external procedure that draws all boxes
EXTRN DrawBoxes:NEAR
; external procedures for input
EXTRN GetExactly5:NEAR
EXTRN SetEchoRow:NEAR

; -------------------------------------------------------
; flow summary (current build)
; - switch to graphics mode
; - call drawboxes (draws 6 rows of 5 boxes each)
; - collect input for each row sequentially (rows 1-6)
; - restore mode, exit
; -------------------------------------------------------

.DATA
    saveMode DB ?         ; to save the original video mode (al from int 10h/ah=0fh)
    currentRow DB 0 ; tracks which row we are in 

.CODE
main PROC
    ; set data segment
    MOV AX, @DATA
    MOV DS, AX

    ; save current text/graphics mode
    MOV AH, 0FH                ; get current video mode
    INT BIOS_VIDEO_INT
    MOV saveMode, AL           ; save mode number from AL

    ; switch to graphics mode 12h
    MOV AH, 00H        ; set video mode
    MOV AL, MODE_12
    INT BIOS_VIDEO_INT

    ; draw all boxes (separate module)
    CALL DrawBoxes

    MOV BYTE PTR currentRow, 0

GAME_LOOP:
    ;MOV AL, currentRow
    ;ADD AL, 4
    ; 4 8 12 16 20 24 

    ; Row 1 input (text row 4) -
    MOV AL, 4
    CALL SetEchoRow
    CALL GetExactly5
    
    ; Row 2 input (text row 8)   
    MOV AL, 8
    CALL SetEchoRow
    CALL GetExactly5
    
    ; Row 3 input (text row 12)
    MOV AL, 12
    CALL SetEchoRow
    CALL GetExactly5
    
    ; Row 4 input (text row 16) 
    MOV AL, 16
    CALL SetEchoRow
    CALL GetExactly5
    
    ; Row 5 input (text row 20) 
    MOV AL, 20
    CALL SetEchoRow
    CALL GetExactly5
    
    ; Row 6 input (text row 24) 
    MOV AL, 24
    CALL SetEchoRow
    CALL GetExactly5
    
    ; program exit
LOSE_GAME:
    JMP EXIT_GAME

WIN_GAME:
    ; todo

EXIT_GAME:
    ; restore original video mode
    MOV AH, 00H        ; Set Video Mode
    MOV AL, saveMode   ; Load the saved mode
    INT BIOS_VIDEO_INT

    ; exit program 
    MOV AX, 4C00H
    INT DOS_INT

main ENDP
END main
