%{
// INCLUDE Z C

%}

%token <str> NUM
%token <str> DECLARE IN END
%token <str> IF THEN ELSE ENDIF
%token <str> WHILE DO ENDWHILE ENDDO FOR FROM ENDFOR
%token <str> WRITE READ PIDENTIFIER SEMICOLON TO DOWNTO
%token <str> LEFTBRACKET RIGHTBRACKET COLON ASSIGN EQUAL NOTEQUAL LEFTINEQUAL RIGHTINEQUAL LEFTINEQUALEQUAL RIGHTINEQUALEQUAL ADD SUBSTRACT MULTIPLY DIVIDE MOD

%%

program:
DECLARE declarations IN commands END
;

declarations:
declarations PIDENTIFIER SEMICOLON
| declarations PIDENTIFIER LEFTBRACKET NUM COLON NUM RIGHTBRACKET SEMICOLON
|
;

commands:
identifier ASSIGN expression SEMICOLON
| IF condition THEN commands ELSE commands ENDIF
| IF condition THEN commands ENDIF
| WHILE condition DO commands ENDWHILE
| DO commands WHILE condition ENDDO
| FOR pidentifier FROM value TO value DO commands ENDFOR
| FOR pidentifier FROM value DOWNTO value DO commands ENDFOR
| READ identifier SEMICOLON
| WRITE value SEMICOLON
;

expression:
value
| value ADD value
| value SUBSTRACT value
| value MULTIPLY value
| value DIVIDE value
| value MOD value
;

condition:
value EQUAL value
| value NOTEQUAL value
| value LEFTINEQUAL value
| value RIGHTINEQUAL value
| value LEFTINEQUALEQUAL value
| value RIGHTINEQUALEQUAL value
;

value:
NUM
| identifier
;

identifier:
PIDENTIFIER
| PIDENTIFIER LEFTBRACKET PIDENTIFIER RIGHTBRACKET
| PIDENTIFIER LEFTBRACKET NUM RIGHTIDENTIFIER
;

%%
