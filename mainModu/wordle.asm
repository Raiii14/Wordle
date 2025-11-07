; ============================================================================
; COMBINED WORDLE GAME - ALL MODULES IN ONE FILE
; ============================================================================
; This file combines:
; - Main game logic from wordle.asm
; - All service modules (drawbox, getchar, validate, logic, fillbox, getword)
; ============================================================================

.MODEL SMALL

.STACK 64

; ============================================================================
; CONSTANTS
; ============================================================================
; Constants for Video Modes
MODE_12        EQU 12H    ; 640x480, 16 colors (VGA)
BIOS_VIDEO_INT EQU 10H
DOS_INT        EQU 21H

; Box settings
BOX_WIDTH  EQU 54       ; Box width equals 54, immediate address
BOX_HEIGHT EQU 48       ; Reduced from 52 to 48 for better text alignment
BOX_GAP    EQU 10
START_X    EQU 169
START_Y    EQU 46
BOX_COLOR  EQU 0Fh      ; white/high-intensity, to change the intensity, change the 4 bits, instead of 2 bits only

; vertical spacing between rows
ROW_GAP    EQU 16       ; Increased from 10 to 16 for text grid alignment

; Color mappings for VGA mode 12h (16 colors)
COLOR_GRAY   EQU 08h    ; Dark gray for miss (0)
COLOR_YELLOW EQU 0Eh    ; Yellow for present (1)
COLOR_GREEN  EQU 0Ah    ; Green for correct (2)

; ============================================================================
; DATA SECTION - Combined from all modules
; ============================================================================
.DATA

; ---------- From wordle.asm (main) ----------
saveMode DB ?         ; to save the original video mode (al from int 10h/ah=0fh)
currentRow DB 0       ; tracks which row we are in
currentRound DB 1     ; current round number (1-based)
totalRounds DB 3      ; CHANGE THIS to set number of rounds
msg_round DB 'Round $'
msg_roundNum DB '0',0Dh,0Ah,'$' 

; ---------- From drawbox.asm ----------
YBASE      DW 0         ; current row's top Y (in pixels)
ROWS_LEFT  DB 0         ; how many rows to draw (we'll set to 6)

; ---------- From getchar.asm ----------
; buffered input for up to 5 characters + carriage return
input1 DB 05, ?, 06 DUP(?)

; error message shown when user enters a word not in the list
errInvalid DB 'Not in word list - Try again!$'

; center column per box (text grid cols), for 5 boxes left -> right
; computed from START_X=169, BOX_WIDTH=54, BOX_GAP=10
; result: 24, 32, 40, 48, 56 (increments by 8)
colTable DB 24, 32, 40, 48, 56
; active text-row to echo into (top of 8x16 cell). 4 = first row center, 8 = second row center, etc.
RowCenter DB 4

; flag to track if error message is displayed
errorDisplayed DB 0

; ---------- From logic.asm ----------
; target word (5 letters, uppercase)
targetWord DB 'CRANE'

; colors: 0 = gray/miss, 1 = yellow (present), 2 = green (correct position)
colorResults DB 5 DUP(0)

; simple status messages
msg_win DB 'You win!',0Dh,0Ah,'$'
msg_lose DB 'Out of lives. Game over.',0Dh,0Ah,'$'
msg_word DB 'The word was: $'

; ---------- From fillbox.asm ----------
currentColor DB 0       ; Color to fill current box
guessBuffer DW 0        ; Pointer to current guess buffer
colorResultsPtr DW 0   ; Pointer to color results for the current row

; ---------- From getword.asm ----------
; File handling
filename DB 'words.csv',0
filehandle DW 0
fileBuffer DB 512 DUP(0)
bufferSize DW 512

; Word list storage (max 50 words)
wordList DB 250 DUP(0)      ; 50 words * 5 chars each
wordCount DW 0

; Random seed
randomSeed DW 0

; Error messages
errFileOpen DB 'Error: Cannot open words.csv',0Dh,0Ah,'$'
errNoWords DB 'Error: No words found',0Dh,0Ah,'$'
errReadFile DB 'Error: Cannot read file',0Dh,0Ah,'$'

; ============================================================================
; CODE SECTION
; ============================================================================
.CODE

; ============================================================================
; MAIN PROCEDURE (from wordle.asm)
; ============================================================================
main PROC
    ; set data segment
    MOV AX, @DATA
    MOV DS, AX

    ; Initialize word list from CSV file
    CALL InitWordList

    ; save current text/graphics mode
    MOV AH, 0FH                ; get current video mode
    INT BIOS_VIDEO_INT
    MOV saveMode, AL           ; save mode number from AL

ROUND_START:
    ; Load a random target word for this round
    CALL LoadTargetWord

    ; switch to graphics mode 12h
    MOV AH, 00H        ; set video mode
    MOV AL, MODE_12
    INT BIOS_VIDEO_INT

    ; display round number at top
    CALL ShowRoundNumber

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
    ; If ESC was pressed, GetExactly5 returns AL=0 (and CX=0): exit game
    CMP AL, 0
    JE EXIT_GAME
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
    ; Show the target word at the bottom
    CALL ShowTargetWord
    ; Wait for keypress before continuing
    MOV AH, 00H        ; BIOS keyboard - wait for keystroke
    INT 16H            ; Blocks until user presses any key
    ; If ESC was pressed here, exit game instead of proceeding
    CMP AL, 1Bh
    JE  EXIT_GAME
    JMP CHECK_NEXT_ROUND

WIN_GAME:
    ; Show the target word at the bottom
    CALL ShowTargetWord
    ; Wait for keypress before continuing
    MOV AH, 00H        ; BIOS keyboard - wait for keystroke
    INT 16H            ; Blocks until user presses any key
    ; If ESC was pressed here, exit game instead of proceeding
    CMP AL, 1Bh
    JE  EXIT_GAME

CHECK_NEXT_ROUND:
    ; Check if more rounds remaining
    MOV AL, currentRound
    CMP AL, totalRounds
    JGE EXIT_GAME       ; If currentRound >= totalRounds, exit
    
    ; Increment round and start next round
    INC currentRound
    JMP ROUND_START

EXIT_GAME:
    ; restore original video mode
    MOV AH, 00H        ; Set Video Mode
    MOV AL, saveMode   ; Load the saved mode
    INT BIOS_VIDEO_INT

    ; exit program 
    MOV AX, 4C00H
    INT DOS_INT

main ENDP

; ShowRoundNumber - Displays "Round #" centered at top of screen
ShowRoundNumber PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    ; Set cursor to top center (row 1, column 37)
    MOV AH, 02h
    MOV BH, 0           ; Page 0
    MOV DH, 1           ; Row 1
    MOV DL, 37          ; Column 37 (centered)
    INT 10h

    ; Print "Round "
    LEA DX, msg_round
    MOV AH, 09h
    INT 21h

    ; Convert round number to ASCII and display
    MOV AL, currentRound
    ADD AL, '0'         ; Convert to ASCII digit
    MOV msg_roundNum, AL

    ; Print the round number
    LEA DX, msg_roundNum
    MOV AH, 09h
    INT 21h

    POP DX
    POP CX
    POP BX
    POP AX
    RET
ShowRoundNumber ENDP

; ============================================================================
; DRAWBOX.ASM - Box drawing routines
; ============================================================================

; -------------------------------------------------------
; flow summary (current build)
; - called after main switches to VGA mode 12h
; - draw 6 rows total; for each row:
;   - set YBASE to row's top Y position using formula: START_Y + row_index * (BOX_HEIGHT + ROW_GAP)
;   - repeat 5 times (i = 0..4):
;   - compute right (DI) and bottom (BP) edges from START_X/START_Y and BOX_WIDTH/BOX_HEIGHT
;   - draw top line (left → right)
;   - draw bottom line (left → right)
;   - draw left line (top → bottom)
;   - draw right line (top → bottom)
;   - move to next box by adding (BOX_WIDTH + BOX_GAP) to SI (x position)
; - return to caller
; -------------------------------------------------------

DrawBoxes PROC NEAR

        ; draw exactly 2 rows (simple scaler without duplicating code)
        MOV BYTE PTR [ROWS_LEFT], 6

ROW_START:
        ; set YBASE based on which row we're on (0-5, where 0 is top row)
        MOV AL, [ROWS_LEFT]
        MOV AH, 6               ; total rows
        SUB AH, AL              ; AH = current row index (0-5)
        
        ; Calculate Y position: START_Y + row_index * (BOX_HEIGHT + ROW_GAP)
        MOV AL, AH              ; AL = row index
        XOR AH, AH              ; AX = row index
        MOV BX, BOX_HEIGHT
        ADD BX, ROW_GAP         ; BX = BOX_HEIGHT + ROW_GAP
        MUL BX                  ; AX = row_index * (BOX_HEIGHT + ROW_GAP)
        ADD AX, START_Y         ; AX = START_Y + row_offset
        MOV [YBASE], AX
ROW_SETUP_DONE:

        MOV AH, 0Ch
        MOV AL, BOX_COLOR
        MOV BH, 0

        MOV BX, 5                 ; 5 boxes per row
        MOV SI, START_X           ; start X for the row
        ; DI will be loaded from YBASE per box below

    ; The starting loop for drawing the boxes, like the for loop
    ; for (int i = 0; i < 5; i++) - which means this will print a box 5 times
    OUTER_BOX_LOOP:
        MOV DI, [YBASE]           ; top Y for this row

        PUSH BX

        ; sets the size and color of the box
        MOV CX, SI
        ADD CX, BOX_WIDTH

        MOV DX, DI
        ADD DX, BOX_HEIGHT

        MOV DI, CX
        MOV BP, DX

        MOV AH, 0Ch
        MOV AL, BOX_COLOR
        MOV BH, 0

        MOV DX, [YBASE]
        MOV CX, SI
    
    ; draws the top line of a box, from left to right
    TOP_LINE_LOOP:
        CMP CX, DI
        JAE END_TOP_LINE
        INT 10h
        INC CX
        JMP TOP_LINE_LOOP
    END_TOP_LINE:
        MOV DX, BP
        MOV CX, SI

    ; draws the bottom line, from left to right
    BOTTOM_LINE_LOOP:
        CMP CX, DI
        JAE END_BOTTOM_LINE
        INT 10h
        INC CX
        JMP BOTTOM_LINE_LOOP
    END_BOTTOM_LINE:
        MOV CX, SI
        MOV DX, [YBASE]

    ; draws the left line, from top to bottom
    LEFT_LINE_LOOP:
        CMP DX, BP
        JAE END_LEFT_LINE
        INT 10h
        INC DX
        JMP LEFT_LINE_LOOP
    END_LEFT_LINE:
        MOV CX, DI
        MOV DX, [YBASE]

    ; draws the right line, from top to bottom
    RIGHT_LINE_LOOP:
        CMP DX, BP
        JAE END_RIGHT_LINE
        INT 10h
        INC DX
        JMP RIGHT_LINE_LOOP
    END_RIGHT_LINE:
        ADD SI, BOX_WIDTH
        ADD SI, BOX_GAP

        POP BX
        DEC BX
        JNE OUTER_BOX_LOOP

    ; one row finished; if another row remains, set up and draw it
    ; trampoline pattern: short JZ to skip, near JMP back to ROW_START
    DEC BYTE PTR [ROWS_LEFT]
    JZ  DoneRows       ; if zero rows left, skip the jump-back
    JMP ROW_START      ; else, near jump back (no range limit)

DoneRows:
    RET
DrawBoxes ENDP

; ============================================================================
; GETCHAR.ASM - Input handling routines
; ============================================================================

; -------------------------------------------------------
; flow summary (current build)
; - si points to the input buffer; bl holds current length (0..5)
; - loop:
;   - read a key (INT 16h)
;   - if Enter:
;       - if bl == 5 
;           if is valid -> accept finalize buffer (DOS 0Ah layout), print CR/LF, return
;           else ->show error, stay in row
;       - else → keep waiting for more input
;   - else if Backspace and bl > 0:
;       - decrement bl and si; move cursor to row 4 and center column for that index
;       - print the removed character in black to visually erase it
;   - else if key is a letter:
;       - convert lowercase to uppercase; if bl < 5 store it (buffer[si] = AL)
;       - increment bl; move cursor to row 4 and center column for (bl-1)
;       - print the character in bright white
;   - else:
;       - ignore the key and read again
; -------------------------------------------------------

; blocks until exactly 5 characters are entered; retains what was typed if enter is pressed early
; returns:
;   AL = length (always 5 on return)
;   CX = length (5)
;   SI = the pointer to first character (input1+2)

GetExactly5 PROC NEAR
    LEA SI, input1+2     ; si -> first character position in the buffer
    XOR BX, BX         ; bl = length (0..5)

    ; Similar to = while(true)
    ReadLoop:
        ; wait for a keystroke (blocking)
        MOV AH, 00h         ; ah=00h read key
        INT 16h            ; al=ascii (if any), ah=scancode

        ; Clear error message if displayed and user starts typing
        CMP BYTE PTR [errorDisplayed], 1
        JNE SkipErrorClear
        CALL ClearInvalidWordError
        MOV BYTE PTR [errorDisplayed], 0
SkipErrorClear:

        ; ================================================================

        ; Exit early if Escape is pressed
        CMP AL, 1Bh        ; ESC?
        JE  OnEscape

        ; ================================================================

        ; - if(KeyPressed == Enter && i == 5)
        ; - Which means that there are already 5 characters entered

        CMP AL, 0Dh        ; enter?
        JE  OnEnter        ; to prevent jump out of range (limit of +-127), make a function that JMPs to the real function
        JMP AfterEnterCheck

    OnEnter:
        JMP OnEnter_real   ; near jump to real handler (fixes out-of-range)

    ; Handle Escape: signal abort (AL=0, CX=0) and return
    OnEscape:
        XOR AX, AX         ; AL=0 (length), AH=0
        XOR CX, CX         ; CX=0 length
        LEA SI, input1+2   ; SI still points to buffer start (not used by caller)
        RET

    AfterEnterCheck:
        ; - else if(KeyPressed != Backspace)
        ; - This is the function that stores each character in the buffer
        
        CMP AL, 08h         ; backspace?
        JNE NotBackspace


        ; - Checks if the length of the input is at 0
        ; - If equal (JE), goes back to the beginning of the loop
        CMP BL, 0
        JE  ReadLoop        ; nothing to delete

        ; - If not equal, it will erase the last character on the screen
        ; - Think of the instructions below as else {}
        ; ================================================================

        ; update buffer (remove last char)
        DEC BL
        DEC SI

        ; visually erase the removed char at its box center
        ; move cursor to row=4 (center row), col from table by index BL
        ; The push and pop in the stacks are used because we don't want to overwrite what's stored in those registers
        ; So we save those values first, then use the registers for setting the values we need, then restore the previous values
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        PUSH SI
        PUSH DI
        ; =====================================================
        MOV AH, 02h         ; set cursor
        MOV BH, 0           ; page 0
    MOV DH, [RowCenter] ; center row (selectable)
        MOV DI, OFFSET colTable
        XOR CH, CH
        MOV CL, BL          ; index = BL (0..4)
        ADD DI, CX
        MOV DL, [DI]        ; DL = col
        INT 10h

        ; print same removed char in black to overwrite pixels
        MOV AH, 0Eh         ; teletype output
        MOV BH, 0
        PUSH BX             ; save BL=len
        XOR BL, BL          ; BL=0 (black)
        MOV AL, [SI]        ; removed character
        INT 10h
        ; ======================================================
        POP BX
        POP DI
        POP SI
        POP DX
        POP CX
        POP BX
        POP AX
        JMP ReadLoop        ; goes back to the beginning of the loop after erasing the last echoed character


    ; The label/loop for actually storing each character
    NotBackspace:
        ; accept letters only, and converts lowercase to uppercase
        ; if AL in 'A'..'Z' keep it. if in 'a'..'z' convert to upper case. else ignore
        CMP AL, 'A'
        JB  NotLetter
        CMP AL, 'Z'
        JBE LetterOK
        CMP AL, 'a'
        JB  NotLetter
        CMP AL, 'z'
        JA  NotLetter
        AND AL, 0DFh            ; make uppercase
        LetterOK:
            CMP BL, 5
            JB  DoStore         ; short jump if below max
            JMP ReadLoop        ; already at max, ignore extra chars
        NotLetter:
            JMP ReadLoop        ; ignore non-letters
        DoStore:
            ; stores the character in the buffer (like putting a character in an array position)
            MOV [SI], AL
            INC SI
            INC BL
        
    ; echo the character centered in its box using the table
    ; so we save and restore registers to the stack, to avoid overwriting values
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    ; =====================================================
    ; idx = BL-1 (0..4)
    MOV CL, BL
    DEC CL
    MOV DI, OFFSET colTable
    XOR CH, CH
    ADD DI, CX
    MOV DL, [DI]       ; DL = center col for this box
    MOV DH, [RowCenter]     ; active center row
    MOV AH, 02h        ; set cursor
    MOV BH, 0
    INT 10h
    ; draw the character in bright white
    MOV AH, 0Eh
    MOV BH, 0
    PUSH BX            ; preserve BL=len
    MOV BL, 0Fh
    MOV AL, [SI-1]
    INT 10h
    ; =====================================================
    POP BX
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
        JMP ReadLoop
    

    OnEnter_real:
        CMP BL, 5
        JE  HaveFiveChars       ; 
        JMP ReadLoop       ; not enough characters, keep buffer and go back to the starting loop

    HaveFiveChars:
        ; validate word before accepting
        LEA SI, input1+2
        CALL IsValidWord
        CMP AL, 0;
        JE InvalidWord ; jump if word is not in the pool of words

        ; finalize buffer per DOS 0Ah layout for compatibility
        MOV [input1+1], BL       ; actual length
        MOV BYTE PTR [input1+2+5], 0Dh   ; terminating CR
        
        MOV AL, BL
        XOR AH, AH
        MOV CX, AX             ; cx = 5
        LEA SI, input1+2         ; si -> first character
        RET
        
    InvalidWord:
        ; Show error message (stays until user types again)
        CALL ShowInvalidWordError
        MOV BYTE PTR [errorDisplayed], 1
        
        ; Invalid word: clear the input buffer and visually erase typed letters
        ; BL = current length, SI points after last char (input1+2 + BL)
        ; We'll iterate and erase each displayed char then reset BL and SI
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        PUSH SI
        PUSH DI

    ClearLoop:
        CMP BL, 0
        JE ClearDone
        ; Move SI back to last character and decrement length
        DEC SI
        DEC BL

        ; move cursor to row=RowCenter, col from table by index BL
        MOV AH, 02h         ; set cursor
        MOV BH, 0           ; page 0
        MOV DH, [RowCenter] ; center row
        MOV DI, OFFSET colTable
        XOR CH, CH
        MOV CL, BL          ; index = BL (0..4)
        ADD DI, CX
        MOV DL, [DI]        ; DL = col
        INT 10h

        ; print a space in black to overwrite the character
        MOV AH, 0Eh         ; teletype output
        MOV BH, 0
        PUSH BX             ; save BL
        XOR BL, BL          ; BL=0 (black)
        MOV AL, ' '
        INT 10h
        POP BX

        JMP ClearLoop

    ClearDone:
        POP DI
        POP SI
        POP DX
        POP CX
        POP BX
        POP AX
        ; reset buffer pointer and length so user can type a fresh guess
        LEA SI, input1+2
        XOR BL, BL
        JMP ReadLoop
GetExactly5 ENDP

; -------------------------------------------------------
; SetEchoRow
; - sets which text-row (DH) the echo/erase uses
; - usage: AL = row index (e.g., 4 for first row center, 7 for second row center)
; - example: SetEchoRow(7) in Java style
; -------------------------------------------------------
SetEchoRow PROC NEAR
    MOV [RowCenter], AL
    RET
SetEchoRow ENDP

; -------------------------------------------------------
; ShowInvalidWordError
; Displays "Not in word list - Try again!" below the 6 rows of boxes
; (row 27, above where "The word was:" appears at row 28)
; Message stays visible until user starts typing again
; -------------------------------------------------------
ShowInvalidWordError PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; Set cursor position (row 27, column 28 for centering)
    ; This is just above "The word was:" which appears at row 28
    MOV AH, 02h
    MOV BH, 0           ; Page 0
    MOV DH, 27          ; Row 27 (below all boxes, above "The word was:")
    MOV DL, 26          ; Column 28 (centered)
    INT 10h

    ; Display error message in red (color 0Ch)
    LEA SI, errInvalid
ShowErrLoop:
    MOV AL, [SI]
    CMP AL, '$'
    JE ErrDisplayed
    
    MOV AH, 0Eh         ; Teletype output
    MOV BH, 0           ; Page 0
    PUSH BX
    MOV BL, 0Ch         ; Red text
    INT 10h
    POP BX
    
    INC SI
    JMP ShowErrLoop

ErrDisplayed:
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
ShowInvalidWordError ENDP

; -------------------------------------------------------
; ClearInvalidWordError
; Clears the error message by overwriting with spaces
; -------------------------------------------------------
ClearInvalidWordError PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    ; Set cursor to same position as error message
    MOV AH, 02h
    MOV BH, 0
    MOV DH, 27          ; Row 27
    MOV DL, 26          ; Column 28
    INT 10h

    ; Clear the error message by overwriting with spaces
    MOV CX, 29          ; Length of error message
ClrErrLoop:
    MOV AH, 0Eh
    MOV BH, 0
    PUSH BX
    XOR BL, BL          ; Black color
    MOV AL, ' '
    INT 10h
    POP BX
    LOOP ClrErrLoop

    POP DX
    POP CX
    POP BX
    POP AX
    RET
ClearInvalidWordError ENDP

; ============================================================================
; VALIDATE.ASM - Word validation routines
; ============================================================================

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

; ============================================================================
; LOGIC.ASM - Game logic and word comparison
; ============================================================================

; ----------------------------
; LoadTargetWord
; Calls GetRandomWord and copies the result to targetWord
LoadTargetWord PROC NEAR
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI
    
    CALL GetRandomWord      ; SI = pointer to random word
    LEA DI, targetWord
    MOV CX, 5
    
CopyWord:
    MOV AL, [SI]
    MOV [DI], AL
    INC SI
    INC DI
    LOOP CopyWord
    
    POP DI
    POP SI
    POP CX
    POP AX
    RET
LoadTargetWord ENDP

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
; ShowTargetWord
; Displays "The word was: XXXXX" centered at the bottom of the screen
ShowTargetWord PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; Center the text at bottom: "The word was: XXXXX" = 20 chars
    ; Screen width = 80 columns, so center = (80 - 20) / 2 = 30
    ; Screen height = 30 rows (text mode in graphics mode)
    MOV AH, 02h
    MOV BH, 0           ; Page 0
    MOV DH, 28          ; Row 28 (near bottom)
    MOV DL, 30          ; Column 30 (centered)
    INT 10h

    ; Print "The word was: "
    LEA DX, msg_word
    MOV AH, 09h
    INT 21h

    ; Print each letter of the target word
    LEA SI, targetWord
    MOV CX, 5
ShowWordLoop:
    MOV AH, 0Eh         ; Teletype output
    MOV BH, 0
    MOV BL, 0Fh         ; Bright white
    MOV AL, [SI]
    INT 10h
    INC SI
    LOOP ShowWordLoop

    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
ShowTargetWord ENDP

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

    ; pick a random word and load it into targetWord
    CALL LoadTargetWord

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

; ============================================================================
; FILLBOX.ASM - Box filling with colors and text rendering
; ============================================================================

; FillBoxRow
; Input: AL = row number (0-5), SI = pointer to guess buffer (5 chars)
; Reads color results and fills the boxes in the specified row with colors,
; then renders the letters on top
FillBoxRow PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP

    ; Save row number and guess buffer
    MOV BL, AL              ; BL = row number (0-5)
    MOV [guessBuffer], SI   ; Save guess buffer pointer
    PUSH BX                 ; Save row for text rendering later

    ; Get color results array pointer
    CALL GetColorResults    ; Returns SI = pointer to colorResults
    MOV [colorResultsPtr], SI ; Save pointer so text renderer can read colors

    ; Calculate Y position for this row: START_Y + row * (BOX_HEIGHT + ROW_GAP)
    MOV AL, BL              ; AL = row number
    XOR AH, AH              ; AX = row number
    MOV CX, BOX_HEIGHT
    ADD CX, ROW_GAP         ; CX = BOX_HEIGHT + ROW_GAP
    MUL CX                  ; AX = row * (BOX_HEIGHT + ROW_GAP)
    ADD AX, START_Y         ; AX = START_Y + offset
    MOV BP, AX              ; BP = top Y coordinate for this row

    ; Loop through 5 boxes
    MOV CX, 5               ; 5 boxes to fill
    XOR BX, BX              ; BX = box index (0-4)

FillBoxLoop:
    ; Get color for this box
    MOV AL, [SI+BX]         ; AL = color code (0, 1, or 2)
    
    ; Map color code to VGA color
    CMP AL, 2
    JE SetGreenColor
    CMP AL, 1
    JE SetYellowColor
    ; Default to gray
    MOV AL, COLOR_GRAY
    JMP ColorSet
SetYellowColor:
    MOV AL, COLOR_YELLOW
    JMP ColorSet
SetGreenColor:
    MOV AL, COLOR_GREEN
ColorSet:
    MOV [currentColor], AL

    ; Calculate X position for this box: START_X + box_index * (BOX_WIDTH + BOX_GAP)
    PUSH BX
    PUSH CX
    MOV AX, BX              ; AX = box index
    MOV CX, BOX_WIDTH
    ADD CX, BOX_GAP         ; CX = BOX_WIDTH + BOX_GAP
    MUL CX                  ; AX = box_index * (BOX_WIDTH + BOX_GAP)
    ADD AX, START_X         ; AX = START_X + offset
    MOV DI, AX              ; DI = left X coordinate
    POP CX
    POP BX

    ; Fill this box
    PUSH BX
    PUSH CX
    PUSH SI
    MOV AX, DI              ; AX = left X
    MOV DX, BP              ; DX = top Y
    CALL FillSingleBox
    POP SI
    POP CX
    POP BX

    ; Move to next box
    INC BX
    LOOP FillBoxLoop

    ; Now render the text on top of the colored boxes
    POP BX                  ; Restore row number
    PUSH BX
    CALL RenderTextOnRow

    POP BX                  ; Restore and discard saved row number
    POP BP
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
FillBoxRow ENDP

; FillSingleBox
; Input: AX = left X, DX = top Y
; Fills a single box with currentColor (interior only, not borders)
FillSingleBox PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH BP
    ; Calculate interior boundaries (skip 1-pixel border on each side)
    ; AX = left X, DX = top Y (as passed in)
    ; We'll compute:
    ;   CX = startX = AX + 1
    ;   DI = endX  = AX + BOX_WIDTH - 1  (loop uses CX < DI)
    ;   BP = endY  = topY + BOX_HEIGHT - 1 (loop uses DX < BP)

    ; start X (interior)
    MOV CX, AX
    INC CX                  ; CX = AX + 1

    ; end X (exclusive bound)
    MOV DI, AX
    ADD DI, BOX_WIDTH       ; DI = AX + BOX_WIDTH (exclusive bound so we draw while X < DI)

    ; start Y (interior)
    MOV BP, DX
    INC BP                  ; BP will temporarily hold startY (BP = topY + 1)
    MOV DX, BP              ; DX = startY

    ; end Y (exclusive bound)
    MOV BP, DX
    ADD BP, BOX_HEIGHT
    DEC BP                  ; BP = startY + BOX_HEIGHT - 1 -> effectively topY + BOX_HEIGHT - 1

    ; Setup for pixel drawing (INT 10h AH=0Ch)
    MOV AH, 0Ch             ; Write pixel function
    MOV AL, [currentColor]  ; Color
    MOV BH, 0               ; Page 0

FillRowLoop:
    CMP DX, BP
    JAE FillDone

    PUSH CX                 ; save start X
    MOV SI, CX              ; use SI as running X

FillColLoop:
    CMP SI, DI
    JAE FillRowDone

    ; Draw pixel at (SI, DX)
    MOV CX, SI              ; set CX = X for INT 10h (CX used as column by BIOS)
    INT 10h

    INC SI
    JMP FillColLoop

FillRowDone:
    POP CX                  ; restore CX (start X)
    INC DX                  ; next scanline
    JMP FillRowLoop

FillDone:
    POP BP
    POP DI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
FillSingleBox ENDP

; RenderTextOnRow
; Input: BX = row number (0-5)
; Renders the guessed letters on top of the colored boxes in bright white
; Uses the saved guessBuffer pointer
RenderTextOnRow PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH BP
    PUSH SI
    PUSH DI

    ; Calculate text row: same formula as main game loop
    ; row 0 -> 4, row 1 -> 8, row 2 -> 12, etc.
    ; Formula: 4 + (row * 4)
    MOV AL, BL              ; AL = row number
    MOV CL, 4
    MUL CL                  ; AX = row * 4
    ADD AL, 4               ; AL = 4 + (row * 4)
    MOV DH, AL              ; DH = text row

    ; Get the guess buffer pointer and color results pointer
    MOV BX, [guessBuffer]   ; BX = base of guess buffer for character reads
    MOV BP, [colorResultsPtr] ; BP = pointer to color results array

    ; Column positions for centered text in each box: 24, 32, 40, 48, 56
    ; Draw each of 5 letters
    MOV CX, 5               ; 5 letters
    XOR DI, DI              ; DI = letter index

RenderLetterLoop:
    ; Calculate column: 24 + (index * 8)
    MOV AX, DI              ; AX = index (16-bit)
    MOV DL, 8
    MUL DL                  ; AX = index * 8
    ADD AL, 24              ; AL = 24 + (index * 8)
    PUSH DX                 ; Save DH (row)
    MOV DL, AL              ; DL = column
    
    ; Set cursor position
    MOV AH, 02h             ; Set cursor position
    MOV BH, 0               ; Page 0
    ; DH already has row, DL has column
    INT 10h

    ; Draw the letter using teletype output (AH=0Eh). Keep AL as the
    ; character and set BL to attribute (background<<4 | foreground).
    MOV AL, [BX+DI]         ; AL = character from guess buffer

    ; Determine background color for this letter from color results (BP base)
    MOV AH, [BP+DI]         ; AH = color code (0,1,2)
    CMP AH, 2
    JE Render_SetGreen2
    CMP AH, 1
    JE Render_SetYellow2
    ; Default to gray
    MOV AH, COLOR_GRAY
    JMP Render_ColorReady2
Render_SetYellow2:
    MOV AH, COLOR_YELLOW
    JMP Render_ColorReady2
Render_SetGreen2:
    MOV AH, COLOR_GREEN
Render_ColorReady2:
    ; AH now contains background color nibble. Build attribute in AL while
    ; preserving the character in AX via the stack, then set BL and call INT 10h.
    PUSH CX                 ; save loop counter
    PUSH BX                 ; save BX (we'll overwrite BL temporarily)
    PUSH AX                 ; save AX (character in AL)
    MOV AL, AH              ; AL = background nibble
    SHL AL, 4               ; AL = background << 4
    OR AL, 0Fh              ; AL = attribute (bg<<4 | bright white)
    MOV BL, AL              ; BL = attribute
    POP AX                  ; restore AX so AL = original character
    MOV AH, 0Eh             ; teletype output (AL = char, BL = attribute)
    MOV BH, 0               ; page 0
    INT 10h
    POP BX                  ; restore BX
    POP CX                  ; restore loop counter
    
    POP DX                  ; Restore DH
    INC DI
    LOOP RenderLetterLoop

    POP DI
    POP SI
    POP BP
    POP DX
    POP CX
    POP BX
    POP AX
    RET
RenderTextOnRow ENDP

; ============================================================================
; GETWORD.ASM - Word list management and random word selection
; ============================================================================

; InitWordList - Load words from CSV file
InitWordList PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    
    ; Open file
    CALL OpenFile
    JC InitError
    
    ; Read file
    CALL ReadFile
    JC InitError
    
    ; Parse words (CX already contains bytes read)
    CALL ParseWords
    
    ; Check if we got any words
    CMP wordCount, 0
    JE InitNoWords
    
    ; Initialize random seed
    CALL InitRandomSeed
    
    JMP InitSuccess

InitNoWords:
    LEA DX, errNoWords
    MOV AH, 09h
    INT 21h
    JMP InitExit

InitError:
    ; Error message already displayed by sub-procedures
    JMP InitExit

InitSuccess:
    ; Success - wordCount contains number of words loaded

InitExit:
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
InitWordList ENDP

; OpenFile - Opens words.csv
; Returns: CF=0 success, CF=1 error
OpenFile PROC NEAR
    PUSH AX
    PUSH DX
    
    ; Open file for reading
    MOV AH, 3Dh         ; DOS open file
    MOV AL, 0           ; Read-only mode
    LEA DX, filename
    INT 21h
    JC OpenFileFail
    
    MOV filehandle, AX
    CLC                 ; Clear carry = success
    JMP OpenFileExit

OpenFileFail:
    LEA DX, errFileOpen
    MOV AH, 09h
    INT 21h
    STC                 ; Set carry = error

OpenFileExit:
    POP DX
    POP AX
    RET
OpenFile ENDP

; ReadFile - Reads file into buffer
; Returns: CF=0 success (CX=bytes read), CF=1 error
ReadFile PROC NEAR
    PUSH AX
    PUSH BX
    PUSH DX
    
    ; Read from file
    MOV AH, 3Fh         ; DOS read file
    MOV BX, filehandle
    LEA DX, fileBuffer
    MOV CX, bufferSize
    INT 21h
    JC ReadFileFail
    
    ; CX now contains bytes read
    PUSH CX             ; Save bytes read
    
    ; Close file
    MOV AH, 3Eh
    MOV BX, filehandle
    INT 21h
    
    POP CX              ; Restore bytes read
    CLC                 ; Clear carry = success
    JMP ReadFileExit

ReadFileFail:
    ; Close file
    MOV AH, 3Eh
    MOV BX, filehandle
    INT 21h
    
    LEA DX, errReadFile
    MOV AH, 09h
    INT 21h
    STC                 ; Set carry = error

ReadFileExit:
    POP DX
    POP BX
    POP AX
    RET
ReadFile ENDP

; ParseWords - Parse buffer and extract words
; Input: CX = buffer size
ParseWords PROC NEAR
    PUSH AX
    PUSH BX
    PUSH SI
    PUSH DI
    
    LEA SI, fileBuffer  ; Source
    LEA DI, wordList    ; Destination
    MOV wordCount, 0
    MOV BX, 0           ; Letter counter

ParseLoop:
    CMP CX, 0
    JE ParseDone
    
    MOV AL, [SI]
    INC SI
    DEC CX
    
    ; Check for comma or end of line
    CMP AL, ','
    JE ParseWordEnd
    CMP AL, 0Dh         ; CR
    JE ParseWordEnd
    CMP AL, 0Ah         ; LF
    JE ParseWordEnd
    CMP AL, 0           ; NULL
    JE ParseWordEnd
    
    ; Convert to uppercase
    CMP AL, 'a'
    JB ParseStoreChar
    CMP AL, 'z'
    JA ParseStoreChar
    SUB AL, 32          ; Convert to uppercase

ParseStoreChar:
    MOV [DI], AL
    INC DI
    INC BX
    JMP ParseLoop

ParseWordEnd:
    ; Check if word is exactly 5 letters
    CMP BX, 5
    JNE ParseResetWord
    
    ; Valid word - increment count
    INC wordCount
    MOV BX, 0
    JMP ParseLoop

ParseResetWord:
    ; Invalid word length - reset
    SUB DI, BX
    MOV BX, 0
    JMP ParseLoop

ParseDone:
    POP DI
    POP SI
    POP BX
    POP AX
    RET
ParseWords ENDP

; InitRandomSeed - Initialize random seed from system time
InitRandomSeed PROC NEAR
    PUSH AX
    PUSH CX
    PUSH DX
    
    ; Get system time
    MOV AH, 2Ch         ; DOS get time
    INT 21h
    ; Returns: CH=hour, CL=minute, DH=second, DL=hundredths
    
    ; Combine into seed
    MOV AL, DH          ; Seconds
    MOV AH, DL          ; Hundredths
    MOV randomSeed, AX
    
    POP DX
    POP CX
    POP AX
    RET
InitRandomSeed ENDP

; GetRandomWord - Returns pointer to random word
; Returns: SI = pointer to random word (5 chars)
GetRandomWord PROC NEAR
    PUSH AX
    PUSH BX
    PUSH DX
    
    ; Simple LCG: seed = (seed * 25173 + 13849) mod 65536
    MOV AX, randomSeed
    MOV BX, 25173
    MUL BX
    ADD AX, 13849
    MOV randomSeed, AX
    
    ; Get random index: AX mod wordCount
    XOR DX, DX
    DIV wordCount       ; DX = AX mod wordCount
    
    ; Calculate offset: DX * 5
    MOV AX, DX
    MOV BX, 5
    MUL BX
    
    ; Get pointer to word
    LEA SI, wordList
    ADD SI, AX
    
    POP DX
    POP BX
    POP AX
    RET
GetRandomWord ENDP

END main