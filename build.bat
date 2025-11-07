@ECHO OFF
TASM mainModu\wordle.asm
TASM services\services.asm


TLINK wordle.obj+services.obj
wordle

ECHO Done.
