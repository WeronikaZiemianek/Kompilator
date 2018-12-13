%{
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <string>
#include <map>
#include <vector>
using namespace std;

typedef struct {
	string name;
    string type; //NUM, PIDENTIFIER, ARR
    int initialized;
    int index;
	  long long int memory;
	  long long int local;
  	long long int arraySize;
} Identifier;

map<string, Identifier> ppidentifierStack;
vector<string> asmStack;

void createPidentifier(Identifier *s, string name, long long int isLocal,
    long long int isArray, string type);
void insertPidentifier(string key, Identifier i);
void removePidentifier(string key);
}%
%token <str> NUM
%token <str> DECLARE IN END
%token <str> IF THEN ELSE ENDIF
%token <str> WHILE DO ENDWHILE ENDDO FOR FROM ENDFOR
%token <str> WRITE READ PIDENTIFIER SEMICOLON TO DOWNTO
%token <str> LEFTBRACKET RIGHTBRACKET COLON ASSIGN EQUAL NOTEQUAL LEFTINEQUAL RIGHTINEQUAL LEFTINEQUALEQUAL RIGHTINEQUALEQUAL ADD SUBSTRACT MULTIPLY DIVIDE MOD
%%
program:
    DECLARATION declarations IN commands END {
        asmStack.push_back("HALT");
    }
;

declarations:
  declarations PIDENTIFIER {
     if(ppidentifierStack.find($2)!=ppidentifierStack.end()) {
         cout << "Błąd linia: " << yylineno << " - Redundancja deklaracji " << $<str>2 << endl;
         exit(1);
     }
     else {
         Identifier s;
         createPidentifier(&s, $2, 0, 0, "PIDENTIFIER");
         insertPidentifier($2, s);
     }
 }
|  declarations PIDENTIFIER LEFTBRACKET NUM COLON NUM RIGHTBRACKET {
     if(pidentifierStack.find($2)!=pidentifierStack.end()) {
         cout << "Błąd linia: " << yylineno << " - Redundancja deklaracji zmiennej tablicowej " << $<str>2 << endl;
         exit(1);
     }
     else if (atoll($6) <= 0) {
         cout << "Błąd linia: " << yylineno << " - Deklaracja zmiennej tablicowej " << $<str>2 << " o dlugosci zero" << endl;
         exit(1);
     }
     else if (atoll($4) > atoll($6)) {
         cout << "Błąd linia: " << yylineno << " - Deklaracja zmiennej tablicowej " << $<str>2 << " o wiekszym zakresie poczatkowym" << endl;
         exit(1);
     }
     else {
         long long int size = atoll($6)-atoll($4) + 1;
         Identifier s;
         createPidentifier(&s, $2, 0, size, "ARR");
         insertPidentifier($2, s);
//         memCounter += size;
//         setRegister(to_string(s.mem+1));
//         registerToMem(s.mem);
     }
 }
|
;
commands:
    commands command
|   command
;
%%
void createPidentifier(Identifier *s, string name, long long int isLocal,
    long long int isArray, string type){
    s->name = name;
    s->mem = memCounter;
    s->type = type;
    s->initialized = 0;
    s->local = isLocal;
    s->tableSize = isArray;
}

void insertPidentifier(string key, Identifier i) {
    if(pidentifierStack.count(key) == 0) {
        pidentifierStack.insert(make_pair(key, i));
        pidentifierStack.at(key).counter = 0;
//        memCounter++;
    }
    else {
        pidentifierStack.at(key).counter = pidentifierStack.at(key).counter+1;
    }
}

void removePidentifier(string key) {
    if(pidentifierStack.count(key) > 0) {
        if(pidentifierStack.at(key).counter > 0) {
            pidentifierStack.at(key).counter = pidentifierStack.at(key).counter-1;
        }
        else {
            pidentifierStack.erase(key);
//            memCounter--;
        }
    }
}

int main(int argv, char* argc[]){
	return 0;
}
