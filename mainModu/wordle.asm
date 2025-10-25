.MODEL SMALL

.STACK 64

; Constants for Video Modes
MODE_12        EQU 12H    ; 640x480, 16 colors (VGA)
BIOS_VIDEO_INT EQU 10H
DOS_INT        EQU 21H

; external procedure that draws all boxes
EXTRN DrawBoxes:NEAR
; external procedures for input
EXTRN GetInput:NEAR
EXTRN GetExactly5:NEAR

; -------------------------------------------------------
; flow summary (current build)
; - switch to graphics mode
; - call drawboxes (draws one row of 5 boxes)
; - wait for key, restore mode, exit
; -------------------------------------------------------

.DATA
    saveMode DB ?          ; to save the original video mode (al from int 10h/ah=0fh)

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
    
    ; after drawing, read exactly 5 characters (no echo, retains partial input)
    CALL GetExactly5         ; blocks until 5 chars collected
    
    ; program exit

    ; restore original video mode
    MOV AH, 00H        ; Set Video Mode
    MOV AL, saveMode   ; Load the saved mode
    INT BIOS_VIDEO_INT

    ; exit program 
    MOV AX, 4C00H
    INT DOS_INT

main ENDP
END main
