@ECHO OFF
TASM mainModu\wordle.asm

TLINK wordle.obj
wordle

ECHO Done.
