@ECHO OFF
TASM mainModu\wordle.asm
TASM services\drawbox.asm
TASM services\getchar.asm, getchar.obj
TASM services\validate.asm
TASM services\logic.asm
TASM services\fillbox.asm
TASM services\getword.asm

TLINK wordle.obj+drawbox.obj+getchar.obj+validate.obj+logic.obj+fillbox.obj+getword.obj
wordle

ECHO Done.
