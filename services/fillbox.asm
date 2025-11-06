; fills boxes with colors based on comparison results
; rendering for input feedback

.MODEL SMALL

; Box settings (must match drawbox.asm)
BOX_WIDTH  EQU 54
BOX_HEIGHT EQU 48
BOX_GAP    EQU 10
START_X    EQU 169
START_Y    EQU 46
ROW_GAP    EQU 16

; Color mappings for VGA mode 12h (16 colors)
COLOR_GRAY   EQU 08h    ; Dark gray for miss (0)
COLOR_YELLOW EQU 0Eh    ; Yellow for present (1)
COLOR_GREEN  EQU 0Ah    ; Green for correct (2)

.DATA
currentColor DB 0       ; Color to fill current box
guessBuffer DW 0        ; Pointer to current guess buffer
colorResultsPtr DW 0   ; Pointer to color results for the current row

.CODE
PUBLIC FillBoxRow
EXTRN GetColorResults:NEAR
EXTRN GetExactly5:NEAR

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

    ; Calculate boundaries (interior, skip 1-pixel border)
    MOV CX, AX              ; CX = start X
    INC CX                  ; Skip left border
    MOV DI, AX
    ADD DI, BOX_WIDTH
    DEC DI                  ; DI = end X (skip right border)
    
    MOV DX, DX              ; DX already has top Y
    INC DX                  ; Skip top border
    MOV BP, DX
    ADD BP, BOX_HEIGHT
    DEC BP                  ; BP = end Y (skip bottom border)

    ; Setup for pixel drawing
    MOV AH, 0Ch             ; Write pixel
    MOV AL, [currentColor]  ; Color
    MOV BH, 0               ; Page 0

    ; Fill row by row
    MOV DX, DX              ; Start from top + 1
    INC DX
FillRowLoop:
    CMP DX, BP
    JAE FillDone
    
    PUSH CX                 ; Save start X
FillColLoop:
    CMP CX, DI
    JAE FillRowDone
    
    ; Draw pixel at (CX, DX)
    INT 10h
    
    INC CX
    JMP FillColLoop

FillRowDone:
    POP CX                  ; Restore start X
    INC DX
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

END