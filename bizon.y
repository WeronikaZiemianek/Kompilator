%{
  #include <math.h>
  #include <stdio.h>
  #include <string.h>
  #include <stdlib.h>
  #include <ctype.h>
  #include <stdarg.h>
  #include <iostream>
  #include <fstream>
  #include <string>
  #include <map>
  #include <vector>
  #include <algorithm>

  using namespace std;

  int yylex();
  extern int yylineno;
  int yyerror(const string str);

%}

%union {
    char* str;
    long long int num;
}


%token <str> NUM
%token <str> DECLARE IN END
%token <str> IF THEN ELSE ENDIF
%token <str> WHILE DO ENDWHILE ENDDO FOR FROM ENDFOR
%token <str> WRITE READ PIDENTIFIER SEMICOLON TO DOWNTO
%token <str> LEFTBRACKET RIGHTBRACKET COLON ASSIGN EQUAL NOTEQUAL LEFTINEQUAL RIGHTINEQUAL LEFTINEQUALEQUAL RIGHTINEQUALEQUAL ADD SUBSTRACT MULTIPLY DIVIDE MOD

%type <str> value
%type <str> identifier
%%

program:
    DECLARE declarations IN commands END {
        printf("HALT\n");
    }
;

declarations:
declarations PIDENTIFIER SEMICOLON {}
|   declarations PIDENTIFIER LEFTBRACKET NUM COLON NUM RIGHTBRACKET SEMICOLON {}
|
;

commands:
    commands command
|   command
;

command:
identifier ASSIGN expression SEMICOLON {}
| IF condition THEN commands ELSE commands ENDIF {}
| IF condition THEN commands ENDIF {}
| WHILE condition DO commands ENDWHILE {}
| DO commands WHILE condition ENDDO {}
| FOR PIDENTIFIER FROM value TO value DO commands ENDFOR {}
| FOR PIDENTIFIER FROM value DOWNTO value DO commands ENDFOR {}
| READ identifier SEMICOLON {}
| WRITE value SEMICOLON {}
|
;

expression:
value {}
| value ADD value {}
| value SUBSTRACT value {}
| value MULTIPLY value {}
| value DIVIDE value {}
| value MOD value {}
;

condition:
value EQUAL value {}
| value NOTEQUAL value {}
| value LEFTINEQUAL value {}
| value RIGHTINEQUAL value {}
| value LEFTINEQUALEQUAL value {}
| value RIGHTINEQUALEQUAL value {}
;

value:
NUM {}
| identifier
;

identifier:
PIDENTIFIER {}
| PIDENTIFIER LEFTBRACKET PIDENTIFIER RIGHTBRACKET {}
| PIDENTIFIER LEFTBRACKET NUM RIGHTBRACKET {}
;

%%

int main(int argv, char* argc[]){
  yyparse();
	return 0;
}

int yyerror(string str){
    cout << "Błąd [okolice linii " << yylineno << \
    "]: " << str << endl;
    exit(1);
}
