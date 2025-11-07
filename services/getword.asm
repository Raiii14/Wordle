; getword.asm
; Reads 5-letter words from a CSV file and returns a random one

.MODEL SMALL

.DATA
; File handling
filename DB 'words.csv',0
filehandle DW 0
fileBuffer DB 512 DUP(0)
bufferSize DW 512

; Word list storage (max 50 words)
PUBLIC wordList
PUBLIC wordCount
wordList DB 250 DUP(0)      ; 50 words * 5 chars each
wordCount DW 0

; Random seed
randomSeed DW 0

; Error messages
errFileOpen DB 'Error: Cannot open words.csv',0Dh,0Ah,'$'
errNoWords DB 'Error: No words found',0Dh,0Ah,'$'
errReadFile DB 'Error: Cannot read file',0Dh,0Ah,'$'

.CODE
PUBLIC GetRandomWord
PUBLIC InitWordList

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

END