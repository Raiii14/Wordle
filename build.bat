@ECHO OFF
TASM mainModu\wordle.asm || GOTO :error
TASM services\drawbox.asm || GOTO :error
TASM services\getchar.asm || GOTO :error
TASM services\logic.asm || GOTO :error
TASM services\colormap.asm || GOTO :error
TASM services\fillbox.asm || GOTO :error
TASM services\getword.asm || GOTO :error

TLINK wordle.obj+drawbox.obj+getchar.obj+logic.obj+colormap.obj+fillbox.obj+getword.obj || GOTO :error
wordle || GOTO :error

GOTO :end

:error
ECHO Error: Premature exit.
GOTO :end

:end
ECHO Done.
