
.MODEL SMALL

.STACK 64

; Constants for Video Modes
MODE_12        EQU 12H    ; 640x480, 16 colors (VGA)
BIOS_VIDEO_INT EQU 10H
DOS_INT        EQU 21H

; External UI procedures
; external procedure that draws all boxes
EXTRN DrawBoxes:NEAR
; external procedures for input
EXTRN GetExactly5:NEAR
EXTRN SetEchoRow:NEAR

; External game logic procedures (NEW)
EXTRN CompareWords:NEAR
EXTRN GetColorResults:NEAR
EXTRN IsWordCorrect:NEAR
EXTRN FillBoxRow:NEAR

; External word service
EXTRN InitWordList:NEAR
EXTRN LoadTargetWord:NEAR
EXTRN ShowTargetWord:NEAR


; External game logic procedures
; -------------------------------------------------------
; Todo, not udpated
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

    ; Initialize word list from CSV file
    CALL InitWordList
    
    ; Load a random target word for this game
    CALL LoadTargetWord

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
    MOV AL, currentRow ;starts at 0
    MOV BL, 4 ; set 4 to bl since we can't multiply immediately
    MUL BL ; multiply 4 to the al register
    
    ADD AL, 4 ;offset 
    ; 4 8 12 16 20 24

    ; get input (bases it on al). al 4 is first row
    CALL SetEchoRow
    CALL GetExactly5
    ; SI now points to the guess buffer (returned by GetExactly5)
    PUSH SI             ; Save guess buffer pointer for FillBoxRow
    
    ; compare the guess to target
    CALL CompareWords
    
    ; get the color results (return should be like an array)
    CALL GetColorResults
    
    ; fill boxes with colors and render text
    POP SI              ; Restore guess buffer pointer
    MOV AL, currentRow
    CALL FillBoxRow
    
    ; Check if correct
    CALL IsWordCorrect
    CMP AL, 1
    JE WIN_GAME
    
    ; check remaining attempts
    INC currentRow ;increment row by 1
    CMP currentRow, 6 ;internally subtract currentRow by 6
    JL GAME_LOOP ;jump if less than 6 (checks negative flag)

LOSE_GAME:
    ; Show the target word at the top
    CALL ShowTargetWord
    ; Wait for keypress before exiting
    MOV AH, 00H        ; BIOS keyboard - wait for keystroke
    INT 16H            ; Blocks until user presses any key
    JMP EXIT_GAME

WIN_GAME:
    ; Show the target word at the top
    CALL ShowTargetWord
    ; Wait for keypress before exiting
    MOV AH, 00H        ; BIOS keyboard - wait for keystroke
    INT 16H            ; Blocks until user presses any key

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
