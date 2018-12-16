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
void sub(Identifier a, Identifier b, int isINC, int isRemoval);
void subTab(Identifier a, Identifier b, Identifier aIndex, Identifier bIndex, int isINC, int isRemoval);

Identifier assignTarget;
string expressionArguments[2] = {"-1", "-1"};
%}

%token <str> NUM
%token <str> DECLARE IN END
%token <str> IF THEN ELSE ENDIF
%token <str> WHILE DO ENDWHILE ENDDO FOR FROM ENDFOR
%token <str> WRITE READ PIDENTIFIER SEMICOLON TO DOWNTO
%token <str> LEFTBRACKET RIGHTBRACKET COLON ASSIGN EQUAL NOTEQUAL LEFTINEQUAL RIGHTINEQUAL LEFTINEQUALEQUAL RIGHTINEQUALEQUAL ADD SUBSTRACT MULTIPLY DIVIDE MOD
%%
program:
    DECLARE declarations IN commands END {
        asmStack.push_back("HALT");
    }
;

declarations:
  declarations PIDENTIFIER {
     if(pppidentifierStack.find($2)!=pppidentifierStack.end()) {
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
     if(ppidentifierStack.find($2)!=ppidentifierStack.end()) {
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

command:
;

value:
    NUM {
    // co to za assignFlag
        if(assignFlag){
            cout << "Błąd linia: " << yylineno << " - Zmiana wartosci stalej" << endl;
           	exit(1);
      	}
        Identifier s;
        // spod 1 bo to pierwsza wartosc po value
      	createPidentifier(&s, $1, 0, 0, "NUM");
        insertPidentifier($1, s);
        // zwizek z expression i command expressionArgument
      	if (expressionArguments[0] == "-1"){
      		expressionArguments[0] = $1;
      	}
      	else{
      		expressionArguments[1] = $1;
      	}
    }
|   identifier
;

identifier:
PIDENTIFIER {
        if(pidentifierStack.find($1) == pidentifierStack.end()) {
            cout << "Błąd linia: " << yylineno << " Niezadeklarowana zmiennna " << $1 << endl;
            exit(1);
        }
        if(pidentifierStack.at($1).tableSize == 0) {
            if(!assignFlag){
                if(pidentifierStack.at($1).initialized == 0) {
                    cout << "Błąd linia: " << yylineno << "Uzycie niezainicjalizowanej zmiennej " << $1 << endl;
                    exit(1);
                }
                // expressionArg..
                if (expressionArguments[0] == "-1"){
                    expressionArguments[0] = $1;
                }
                else{
                    expressionArguments[1] = $1;
                }

            }
            else {
            // assign target
                assignTarget = pidentifierStack.at($1);
            }
        }
        else {
          cout << "Błąd linia " << yylineno << "Niepoprawne odwoanie do elementu tablicy " << $1 << endl;
          exit(1);
        }
    }
|   PIDENTIFIER LEFTBRACKET PIDENTIFIER RIGHTBRACKET {
        if(pidentifierStack.find($1) == pidentifierStack.end()) {
            cout << "Błąd linia: " << yylineno << "Niezadeklarowana zmienna " << $1 << endl;
            exit(1);
        }
        if(pidentifierStack.find($3) == pidentifierStack.end()) {
            cout << "Błąd linia " << yylineno << "Niezadeklarowana zmienna " << $1 << endl;
            exit(1);
        }

        if(pidentifierStack.at($1).tableSize == 0) {
            cout << "Błąd linia " << yylineno << "Tablica nie ma zadeklarowanej dlugosci " << $1 << endl;
            exit(1);
        }
        else {
            if(pidentifierStack.at($3).initialized == 0) {
            cout << "Błąd linia: " << yylineno << "Uzycie niezainicjalizowanej zmiennej " << $3 << endl;
            exit(1);
            }
//flagi
            if(!assignFlag){
                //TODO czy wywalać błąd niezainicjalizowanej
                //zmiennej dla elementu tablicy
                if (expressionArguments[0] == "-1"){
                    expressionArguments[0] = $1;
                    argumentsTabIndex[0] = $3;
                }
                else{
                    expressionArguments[1] = $1;
                    argumentsTabIndex[1] = $3;
                }

            }
            else {
                assignTarget = pidentifierStack.at($1);
                tabAssignTargetIndex = $3;
            }
        }
    }
|   PIDENTIFIER LEFTBRACKET NUM RIGHTBRACKET {
        if(pidentifierStack.find($1) == pidentifierStack.end()) {
        cout << "Błąd linia: " << yylineno << "Niezadeklarowana zmienna " << $1 << endl;

            exit(1);
        }

        if(pidentifierStack.at($1).tableSize == 0) {
        cout << "Błąd linia: " << yylineno << "Tablica nie ma zadeklarowanej dlugosci" << $1 << endl;
        exit(1);
        }
        else {
            Identifier s;
            createPidentifier(&s, $3, 0, 0, "NUM");
            insertPidentifier($3, s);

            if(!assignFlag){
                //TODO czy wywalać błąd niezainicjalizowanej
                //zmiennej dla elementu tablicy
                if (expressionArguments[0] == "-1"){
                    expressionArguments[0] = $1;
                    argumentsTabIndex[0] = $3;
                }
                else{
                    expressionArguments[1] = $1;
                    argumentsTabIndex[1] = $3;
                }

            }
            else {
                assignTarget = pidentifierStack.at($1);
                tabAssignTargetIndex = $3;
            }
        }
    }
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
    if(ppidentifierStack.count(key) == 0) {
        ppidentifierStack.insert(make_pair(key, i));
        ppidentifierStack.at(key).counter = 0;
//        memCounter++;
    }
    else {
        ppidentifierStack.at(key).counter = ppidentifierStack.at(key).counter+1;
    }
}

void removePidentifier(string key) {
    if(ppidentifierStack.count(key) > 0) {
        if(ppidentifierStack.at(key).counter > 0) {
            ppidentifierStack.at(key).counter = ppidentifierStack.at(key).counter-1;
        }
        else {
            ppidentifierStack.erase(key);
//            memCounter--;
        }
    }
}

int main(int argv, char* argc[]){
	return 0;
}
