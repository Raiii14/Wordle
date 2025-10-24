@ECHO OFF
TASM mainModu\wordle.asm || GOTO :error
TASM services\drawbox.asm || GOTO :error

TLINK wordle.obj+drawbox.obj || GOTO :error
wordle || GOTO :error

GOTO :end

:error
ECHO Error: Premature exit.
GOTO :end

:end
ECHO Done.
