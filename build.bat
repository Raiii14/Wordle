@ECHO OFF
TASM mainModu\wordle.asm || GOTO :error
TASM services\drawbox.asm || GOTO :error
TASM services\getchar.asm, getchar.obj || GOTO :error
TASM services\validate.asm || GOTO :error
TASM services\logic.asm || GOTO :error
TASM services\fillbox.asm || GOTO :error
TASM services\getword.asm || GOTO :error

TLINK wordle.obj+drawbox.obj+getchar.obj+validate.obj+logic.obj+fillbox.obj+getword.obj || GOTO :error
wordle || GOTO :error

GOTO :end

:error
ECHO Error: Premature exit.
GOTO :end

:end
ECHO Done.
