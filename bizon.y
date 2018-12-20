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

  vector<string> asmStack;
  typedef struct {
    string name;
    // NUMBER/IDENTIFIER/ARRAY
    string type;
    long long int isLocal;
    int isInitialized;
    int counter;
    int move;
  	long long int arraySize;
  } Idef;

  map<string, Idef> idefStack;
  int flagAssign;
  string expressionArgs[2] = {"-1", "-1"};

  void printAsmStack();
  void createIdef(Idef *idef, string name, string type, long long int isLocal, long long int arraySize);
  void insertIdef(string key, Idef i);
  void removeIdef(string key);

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
        asmStack.push_back("HALT");
        printAsmStack();
    }
;

declarations:
declarations PIDENTIFIER SEMICOLON {

  if(idefStack.find($2)!=idefStack.end()) {
      cout << "Błąd: linia " << yylineno << " - Redundancja deklaracji zmiennej " << $<str>2 << "\n";
      exit(1);
  }
  else {
      Idef idef;
      createIdef(&idef, $2, "IDENTIFIER", 0, 0);
      insertIdef($2, idef);
  }
}
| declarations PIDENTIFIER LEFTBRACKET NUM COLON NUM RIGHTBRACKET SEMICOLON {
  
  if(idefStack.find($2)!=idefStack.end()) {
      cout << "Błąd: linia " << yylineno << " - Redundancja deklaracji zmiennej " << $<str>2 << "\n";
      exit(1);
  }

  else if (stoll($4) < 0) {
      cout << "Błąd linia: " << yylineno << " - Deklaracja zmiennej tablicowej o blednej dlugosci, poczatkowy indeks < 0 " << $<str>2 << "\n";
      exit(1);
  }

  else if (atoll($6) < 0) {
      cout << "Błąd linia: " << yylineno << " - Deklaracja zmiennej tablicowej o blednej dlugosci, koncowy indeks < 0 " << $<str>2 << "\n";
      exit(1);
  }

  else if ( (atoll($4) == atoll($6)) || (atoll($6)==0) ) {
      cout << "Błąd linia: " << yylineno << " - Deklaracja zmiennej tablicowej " << $<str>2 << " o dlugosci zero" << "\n";
      exit(1);
  }

  else if (atoll($4) > atoll($6)) {
          cout << "Błąd linia: " << yylineno << " - Deklaracja zmiennej tablicowej " << $<str>2 << " o wiekszym zakresie poczatkowym niz koncowym" << "\n";
          exit(1);
  }

  else {
      long long int arraySize = atoll($6)-atoll($4) + 1;
      Idef idef;
      createIdef(&idef, $2, "ARR", 0, arraySize);
      insertIdef($2, idef);
  }
}
|
;


commands:
commands command
| command
|
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
NUM {
    if(flagAssign){
        cout << "Błąd linia: " << yylineno << " - Zmiana wartosci stalej - przypisanie wartosci" << "\n";
        exit(1);
    }
    Idef idef;
    createIdef(&idef, $1, "NUMBER", 0, 0);
    insertIdef($1, idef);

    if (expressionArgs[0] == "-1"){
      expressionArgs[0] = $1;
    }
    else{
      expressionArgs[1] = $1;
    }
}
| identifier
;

identifier:
PIDENTIFIER {}
| PIDENTIFIER LEFTBRACKET PIDENTIFIER RIGHTBRACKET {}
| PIDENTIFIER LEFTBRACKET NUM RIGHTBRACKET {}
;

%%
void createIdef(Idef *idef, string name, string type, long long int isLocal, long long int arraySize){
    idef->name = name;
    idef->type = type;

    if(isLocal){
      idef->isLocal = 1;
    }
    else{
      idef->isLocal = 0;
    }

    idef->isInitialized = 0;

    if(arraySize){
      idef->arraySize = arraySize;
    }
    else{
      idef->arraySize = 0;
    }
}

void insertIdef(string key, Idef idef) {
    if(idefStack.count(key) == 0) {
        idefStack.insert(make_pair(key, idef));
        idefStack.at(key).counter = 0;
    }
    else {
        idefStack.at(key).counter = idefStack.at(key).counter++;
    }
}

void removeIdef(string key) {
    if(idefStack.count(key) > 0) {
        if(idefStack.at(key).counter > 0) {
            idefStack.at(key).counter = idefStack.at(key).counter--;
        }
        else {
            idefStack.erase(key);
        }
    }
}

int main(int argv, char* argc[]){
  yyparse();
	return 0;
}

int yyerror(string str){
    cout << "Błąd: linia errorowa" << yylineno << str << "\n";
    exit(1);
}

void printAsmStack() {
	long long int i;
	for(i = 0; i < asmStack.size(); i++)
        cout << asmStack.at(i) << "\n";
}
