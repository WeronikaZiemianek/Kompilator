%option noyywrap
%option yylineno
%option nounput
%{
  #include "DOPISAĆ co będzie includować"
  int yylex();
%}
%com COMMENT

%%
[0-9]+ 		{ yylval = atoi(yytext); return NUM;}

"+"				{ return ADD; }
"-"   			{ return SUBSTRACT; }
"*" 			{ return MULTIPLY; }
"/"   			{ return DIVIDE; }
"%"   			{ return MOD; }
":="			{ return ASSIGN; }
":"			{ return COLON; }

"="				{ return EQUAL; }
"!="			{ return NOTEQUAL; }
"<"				{ return LEFTINEQUAL; }
">"				{ return RIGHTINEQUAL; }
"<="			{ return LEFTINEQUALEQUAL; }
">="			{ return RIGHTINEQUALEQUAL; }

"("				{ return LEFTBRACKET; }
")"				{ return RIGHTBRACKET; }

"DECLARE" { return DECLARE; }
"IN"      { return IN; }
"FOR"			{ return FOR; }
"FROM"			{ return FROM; }
"TO"			{ return TO; }
"DOWNTO"		{ return DOWNTO; }
"IF"			{ return IF; }
"THEN"			{ return THEN; }
"ELSE"			{ return ELSE; }
"ENDIF"			{ return ENDIF; }
"WHILE"			{ return WHILE; }
"DO"			{ return DO; }
"ENDWHILE"		{ return ENDWHILE; }
"ENDDO"			{ return ENDDO; }
"ENDFOR"		{ return ENDFOR; }
";"				{ return SEMICOLON; }

"READ"			{ return READ; }
"WRITE"			{ return WRITE; }

[_a-z]+			{ yylval = atoi(yytext); return PIDENTIFIER; }

"["             	{ BEGIN(COMMENT);       }
<COMMENT>(\n|.)
<COMMENT>"]"  		{ BEGIN(INITIAL);   }
<COMMENT><<EOF>>    { printf("BŁĄD: komentarz nie został zakończony\n"); yyterminate(); }


[ \t]+
[ \n]+
[ \r]+
.				{return ERROR; }
%%
