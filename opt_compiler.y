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

typedef struct {
		string name;
    string type; //NUM, PIDENTIFIER, ARR
    int initialized;
    int counter;
		long long int memory;
		long long int local;
  	long long int arraySize;
} Identifier;

typedef struct {
    long long int placeInStack;
    long long int depth;
} Jump;

map<string, Identifier> identifierStack;
vector<string> codeStack;
vector<Jump> jumpStack;
vector<Identifier> forStack;
/*vector<long long int> initializedMem;*/

int yylex();
extern int yylineno;
int yyerror(const string str);

void pushCommand(string str);
void pushCommandOneArg(string str, long long int num);
void createIdentifier(Identifier *s, string name, long long int isLocal,
    long long int isArray, string type);
void insertIdentifier(string key, Identifier i);
void removeIdentifier(string key);
void createJump(Jump *j, long long int stack, long long int depth);
void registerToMem(long long int memory);
void setRegister(string number);
void zeroRegister();
void memToRegister(long long int memory);
void registerToMem();
void add(Identifier a, Identifier b);
void addTab(Identifier a, Identifier b, Identifier aIndex, Identifier bIndex);
void sub(Identifier a, Identifier b, int isINC, int isRemoval);
void subTab(Identifier a, Identifier b, Identifier aIndex, Identifier bIndex, int isINC, int isRemoval);
void addInt(long long int command, long long int val);
long long int setToTempMem(Identifier a, Identifier aI, long long int tempMem, int isJZERO, int isRemoval);
string decToBin(long long int dec);

long long int memCounter;
long long int depth;
int assignFlag;
int writeFlag;
Identifier assignTarget;
string tabAssignTargetIndex = "-1";
string expressionArguments[2] = {"-1", "-1"};
string argumentsTabIndex[2] = {"-1", "-1"};

%}

%define parse.error verbose
%define parse.lac full
%union {
    char* str;
    long long int num;
}
%token <str> NUM
%token <str> DECLARE IN END IF THEN ELSE ENDIF
%token <str> WHILE DO ENDWHILE ENDDO FOR FROM ENDFOR
%token <str> WRITE READ PIDENTIFIER SEMICOLON TO DOWNTO
%token <str> LEFTBRACKET RIGHTBRACKET COLON ASSIGN EQUAL LEFTINEQUAL RIGHTINEQUAL LEFTINEQUALEQUAL RIGHTINEQUALEQUAL NOTEQUAL ADD SUBSTRACT MULTIPLY DIVIDE MOD

%type <str> value
%type <str> identifier


%%
program:
    DECLARE declarations  IN commands END {
        pushCommand("HALT");
    }
;

declarations :
    declarations  PIDENTIFIER SEMICOLON {
        if(identifierStack.find($2)!=identifierStack.end()) {
            cout << "Błąd linia: " << yylineno << " - Redundancja deklaracji " << $<str>2 << endl;
            exit(1);
        }
        else {
            Identifier s;
            createIdentifier(&s, $2, 0, 0, "PIDENTIFIER");
            insertIdentifier($2, s);
        }
    }
|   declarations  PIDENTIFIER LEFTBRACKET NUM COLON NUM RIGHTBRACKET {
        if(identifierStack.find($2)!=identifierStack.end()) {
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
            long long int size = atoll($4);
            Identifier s;
            createIdentifier(&s, $2, 0, size, "ARR");
            insertIdentifier($2, s);
            memCounter += size;
            setRegister(to_string(s.memory+1));
            registerToMem(s.memory);
        }
    }
|
;

commands:
    commands command
|   command
;

command:
    identifier ASSIGN {
        assignFlag = 0;
    } expression SEMICOLON {
        if(assignTarget.type == "ARR") {
            Identifier index = identifierStack.at(tabAssignTargetIndex);
            if(index.type == "NUM") {
                long long int tabElMem = assignTarget.memory + stoll(index.name) + 1;
                registerToMem(tabElMem);
                removeIdentifier(index.name);
            }
            else {
                registerToMem(0);
                memToRegister(assignTarget.memory);
                pushCommandOneArg("ADD", index.memory);
                registerToMem(2);
                memToRegister(0);
                pushCommandOneArg("STOREI", 2);
            }
        }
        else if(assignTarget.local == 0) {
            registerToMem(assignTarget.memory);
        }
      	else {
            cout << "Błąd linia: " << yylineno << " - Próba modyfikacji iteratora pętli" << endl;
      			exit(1);
      	}
        identifierStack.at(assignTarget.name).initialized = 1;
      	assignFlag = 1;
    }
|   IF {assignFlag = 0;
        depth++;
    } condition {
        assignFlag = 1;
    } THEN commands ifbody

|   WHILE {
        assignFlag = 0;
        depth++;
        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
    } condition {
        assignFlag = 1;
    } DO commands ENDWHILE {
        long long int stack;
        long long int jumpCount = jumpStack.size()-1;
        if(jumpCount > 2 && jumpStack.at(jumpCount-2).depth == depth) {
            stack = jumpStack.at(jumpCount-2).placeInStack;
            pushCommandOneArg("JUMP", stack);
            addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
            addInt(jumpStack.at(jumpCount-1).placeInStack, codeStack.size());
            jumpStack.pop_back();
        }
        else {
            stack = jumpStack.at(jumpCount-1).placeInStack;
            pushCommandOneArg("JUMP", stack);
            addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
        }
        jumpStack.pop_back();
        jumpStack.pop_back();

        depth--;
        assignFlag = 1;
    }
|		DO commands WHILE {

		}
|   FOR PIDENTIFIER {
        if(identifierStack.find($2)!=identifierStack.end()) {
            cout << "Błąd liniia " << yylineno << " - Kolejna deklaracja zmiennej " << $<str>2 << endl;
            exit(1);
        }
        else {
            Identifier s;
            createIdentifier(&s, $2, 1, 0, "PIDENTIFIER");
            insertIdentifier($2, s);
        }
        assignFlag = 0;
        assignTarget = identifierStack.at($2);
        depth++;
    } FROM value forbody
|   READ identifier {
        assignFlag = 1;
    } SEMICOLON {
        if(assignTarget.type == "ARR") {
            Identifier index = identifierStack.at(tabAssignTargetIndex);
            if(index.type == "NUM") {
                pushCommand("GET");
                long long int tabElMem = assignTarget.memory + stoll(index.name) + 1;
                registerToMem(tabElMem);
                removeIdentifier(index.name);
            }
            else {
                memToRegister(assignTarget.memory);
                pushCommandOneArg("ADD", index.memory);
                registerToMem(2);
                pushCommand("GET");
                pushCommandOneArg("STOREI", 2);
            }
        }
        else if(assignTarget.local == 0) {
            pushCommand("GET");
            registerToMem(assignTarget.memory);
        }
        else {
            cout << "Błąd linia " << yylineno << " - Próba modyfikacji iteratora pętli" << endl;
            exit(1);
        }
        identifierStack.at(assignTarget.name).initialized = 1;
        assignFlag = 1;
    }
|   WRITE {
        assignFlag = 0;
        writeFlag = 1;
    } value SEMICOLON {
        Identifier ide = identifierStack.at(expressionArguments[0]);

        if(ide.type == "NUM") {
            setRegister(ide.name);
            removeIdentifier(ide.name);
        }
        else if (ide.type == "PIDENTIFIER") {
            memToRegister(ide.memory);
        }
        else {
            Identifier index = identifierStack.at(argumentsTabIndex[0]);
            if(index.type == "NUM") {
                long long int tabElMem = ide.memory + stoll(index.name) + 1;
                memToRegister(tabElMem);
                removeIdentifier(index.name);
            }
            else {
                memToRegister(ide.memory);
                pushCommandOneArg("ADD", index.memory);
                pushCommandOneArg("STORE", 0);
                pushCommandOneArg("LOADI", 0);
            }
        }
        pushCommand("PUT");
        assignFlag = 1;
        writeFlag = 0;
        expressionArguments[0] = "-1";
        argumentsTabIndex[0] = "-1";
    }
;

ifbody:
    ELSE {
        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
        pushCommand("JUMP");
        long long int jumpCount = jumpStack.size()-2;
        Jump jump = jumpStack.at(jumpCount);
        addInt(jump.placeInStack, codeStack.size());

        jumpCount--;
        if(jumpCount >= 0 && jumpStack.at(jumpCount).depth == depth) {
            addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
        }

        assignFlag = 1;
    } commands ENDIF {
        addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size());
        jumpStack.pop_back();
        jumpStack.pop_back();
        if(jumpStack.size() >= 1 && jumpStack.at(jumpStack.size()-1).depth == depth) {
            jumpStack.pop_back();
        }
        depth--;
        assignFlag = 1;
    }
|   ENDIF {
        long long int jumpCount = jumpStack.size()-1;
        addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
        jumpCount--;
        if(jumpCount >= 0 && jumpStack.at(jumpCount).depth == depth) {
            addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
            jumpStack.pop_back();
        }
        jumpStack.pop_back();
        depth--;
        assignFlag = 1;
    }
;

forbody:
    DOWNTO value DO {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM") {
            setRegister(a.name);
            removeIdentifier(a.name);
        }
        else if(a.type == "PIDENTIFIER") {
            memToRegister(a.memory);
        }
        else {
            Identifier index = identifierStack.at(argumentsTabIndex[0]);
            if(index.type == "NUM") {
                long long int tabElMem = a.memory + stoll(index.name) + 1;
                memToRegister(tabElMem);
                removeIdentifier(index.name);
            }
            else {
                memToRegister(a.memory);
                pushCommandOneArg("ADD", index.memory);
                pushCommandOneArg("STORE", 0);
                pushCommandOneArg("LOADI", 0);
            }
        }
        registerToMem(assignTarget.memory);
        identifierStack.at(assignTarget.name).initialized = 1;

        if(a.type != "ARR" && b.type != "ARR")
            sub(a, b, 1, 1);
        else {
            Identifier aI, bI;
            if(identifierStack.count(argumentsTabIndex[0]) > 0)
                aI = identifierStack.at(argumentsTabIndex[0]);
            if(identifierStack.count(argumentsTabIndex[1]) > 0)
                bI = identifierStack.at(argumentsTabIndex[1]);
            subTab(a, b, aI, bI, 1, 1);
            argumentsTabIndex[0] = "-1";
            argumentsTabIndex[1] = "-1";
        }
        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";

        Identifier s;
        string name = "C" + to_string(depth);
        createIdentifier(&s, name, 1, 0, "PIDENTIFIER");
        insertIdentifier(name, s);

        registerToMem(identifierStack.at(name).memory);
        forStack.push_back(identifierStack.at(assignTarget.name));

        pushCommandOneArg("JZERO", codeStack.size()+2);
        memToRegister(identifierStack.at(name).memory);
        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
        pushCommand("JZERO");
        pushCommand("DEC");
        registerToMem(identifierStack.at(name).memory);

        assignFlag = 1;

    } commands ENDFOR {
        Identifier iterator = forStack.at(forStack.size()-1);
        memToRegister(iterator.memory);
        pushCommand("DEC");
        registerToMem(iterator.memory);

        long long int jumpCount = jumpStack.size()-1;
        long long int stack = jumpStack.at(jumpCount).placeInStack-1;
        pushCommandOneArg("JUMP", stack);
        addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
        jumpStack.pop_back();

        string name = "C" + to_string(depth);
        removeIdentifier(name);
        removeIdentifier(iterator.name);
        forStack.pop_back();

        depth--;
        assignFlag = 1;
    }
|   TO value DO {

        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM") {
            setRegister(a.name);
            /*removeIdentifier(a.name);*/
        }
        else if(a.type == "PIDENTIFIER") {
            memToRegister(a.memory);
        }
        else {
            Identifier index = identifierStack.at(argumentsTabIndex[0]);
            if(index.type == "NUM") {
                long long int tabElMem = a.memory + stoll(index.name) + 1;
                memToRegister(tabElMem);
                /*removeIdentifier(index.name);*/
            }
            else {
                memToRegister(a.memory);
                pushCommandOneArg("ADD", index.memory);
                pushCommandOneArg("STORE", 0);
                pushCommandOneArg("LOADI", 0);
            }
        }
        registerToMem(assignTarget.memory);
        identifierStack.at(assignTarget.name).initialized = 1;

        if(a.type != "ARR" && b.type != "ARR")
            sub(b, a, 1, 1);
        else {
            Identifier aI, bI;
            if(identifierStack.count(argumentsTabIndex[0]) > 0)
                aI = identifierStack.at(argumentsTabIndex[0]);
            if(identifierStack.count(argumentsTabIndex[1]) > 0)
                bI = identifierStack.at(argumentsTabIndex[1]);
            subTab(b, a, bI, aI, 1, 1);
            argumentsTabIndex[0] = "-1";
            argumentsTabIndex[1] = "-1";
        }
        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";

        Identifier s;
        string name = "C" + to_string(depth);
        createIdentifier(&s, name, 1, 0, "PIDENTIFIER");
        insertIdentifier(name, s);

        registerToMem(identifierStack.at(name).memory);
        forStack.push_back(identifierStack.at(assignTarget.name));

        pushCommandOneArg("JZERO", codeStack.size()+2);
        memToRegister(identifierStack.at(name).memory);
        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
        pushCommand("JZERO");
        pushCommand("DEC");
        registerToMem(identifierStack.at(name).memory);

        assignFlag = 1;

    } commands ENDFOR {
        Identifier iterator = forStack.at(forStack.size()-1);
        memToRegister(iterator.memory);
        pushCommand("INC");
        registerToMem(iterator.memory);

        long long int jumpCount = jumpStack.size()-1;
        long long int stack = jumpStack.at(jumpCount).placeInStack-1;
        pushCommandOneArg("JUMP", stack);
        addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
        jumpStack.pop_back();

        string name = "C" + to_string(depth);
        removeIdentifier(name);
        removeIdentifier(iterator.name);
        forStack.pop_back();

        depth--;
        assignFlag = 1;
    }
;

expression:
    value {
        Identifier ide = identifierStack.at(expressionArguments[0]);
        if(ide.type == "NUM") {
            setRegister(ide.name);
            removeIdentifier(ide.name);
        }
        else if(ide.type == "PIDENTIFIER") {
            memToRegister(ide.memory);
        }
        else {
            Identifier index = identifierStack.at(argumentsTabIndex[0]);
            if(index.type == "NUM") {
                long long int tabElMem = ide.memory + stoll(index.name) + 1;
                memToRegister(tabElMem);
                removeIdentifier(index.name);
            }
            else {
                memToRegister(ide.memory);
                pushCommandOneArg("ADD", index.memory);
                pushCommandOneArg("STORE", 0);
                pushCommandOneArg("LOADI", 0);
            }
        }
      	if (!writeFlag) {
            expressionArguments[0] = "-1";
            argumentsTabIndex[0] = "-1";
        }
    }
|   value ADD value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);
        if(a.type != "ARR" && b.type != "ARR")
            add(a, b);
        else {
            Identifier aI, bI;
            if(identifierStack.count(argumentsTabIndex[0]) > 0)
                aI = identifierStack.at(argumentsTabIndex[0]);
            if(identifierStack.count(argumentsTabIndex[1]) > 0)
                bI = identifierStack.at(argumentsTabIndex[1]);
            addTab(a, b, aI, bI);
            argumentsTabIndex[0] = "-1";
            argumentsTabIndex[1] = "-1";
        }
        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
    }
|   value SUBSTRACT value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);
        if(a.type != "ARR" && b.type != "ARR")
            sub(a, b, 0, 1);
        else {
            Identifier aI, bI;
            if(identifierStack.count(argumentsTabIndex[0]) > 0)
                aI = identifierStack.at(argumentsTabIndex[0]);
            if(identifierStack.count(argumentsTabIndex[1]) > 0)
                bI = identifierStack.at(argumentsTabIndex[1]);
            subTab(a, b, aI, bI, 0, 1);
            argumentsTabIndex[0] = "-1";
            argumentsTabIndex[1] = "-1";
        }
        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
    }
|   value MULTIPLY value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);
        Identifier aI, bI;
        if(identifierStack.count(argumentsTabIndex[0]) > 0)
            aI = identifierStack.at(argumentsTabIndex[0]);
        if(identifierStack.count(argumentsTabIndex[1]) > 0)
            bI = identifierStack.at(argumentsTabIndex[1]);

        //TODO czy liczba razy liczba się zmieści w long long int?
        if(a.type == "NUM" && b.type == "NUM") {
            long long int val = stoll(a.name) * stoll(b.name);
            setRegister(to_string(val));
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else if(a.name == "2") {
            if(b.type == "PIDENTIFIER")
                memToRegister(b.memory);
            else if(b.type == "ARR" && bI.type == "NUM") {
                long long int addr = b.memory + stoll(bI.name) + 1;
                memToRegister(addr);
                removeIdentifier(bI.name);
            }
            else {
                memToRegister(b.memory);
                pushCommandOneArg("ADD", bI.memory);
                registerToMem(1);
                pushCommandOneArg("LOADI", 1);
            }
            pushCommand("SHL");
            removeIdentifier(a.name);
        }
        else if(b.name == "2") {
            if(a.type == "PIDENTIFIER")
                memToRegister(a.memory);
            else if(a.type == "ARR" && aI.type == "NUM") {
                long long int addr = a.memory + stoll(aI.name) + 1;
                memToRegister(addr);
                removeIdentifier(aI.name);
            }
            else {
                memToRegister(a.memory);
                pushCommandOneArg("ADD", aI.memory);
                registerToMem(1);
                pushCommandOneArg("LOADI", 1);
            }
            pushCommand("SHL");
            removeIdentifier(b.name);
        }
        else {
            setRegister("0");
            registerToMem(7);

            if(a.type != "ARR" && b.type != "ARR")
                sub(b, a, 0, 0);
            else
                subTab(b, a, bI, aI, 0, 0);

            long long int stackJ = codeStack.size();
            pushCommand("JZERO");

            setToTempMem(b, bI, 6, 0, 0);
            setToTempMem(a, aI, 5, 0, 0);

            pushCommand("JUMP");
            addInt(stackJ, codeStack.size());
            stackJ = codeStack.size()-1;

            setToTempMem(a, aI, 6, 0, 1);
            setToTempMem(b, bI, 5, 0, 1);

            addInt(stackJ, codeStack.size());

            /*memToRegister(5);*/
            stackJ = codeStack.size();
            pushCommandOneArg("JZERO", codeStack.size()+13);
            pushCommandOneArg("JODD", codeStack.size()+2);
            pushCommandOneArg("JUMP", codeStack.size()+4);
            memToRegister(7);
            pushCommandOneArg("ADD", 6);
            registerToMem(7);
            memToRegister(6);
            pushCommand("SHL");
            registerToMem(6);
            memToRegister(5);
            pushCommand("SHR");
            registerToMem(5);
            pushCommandOneArg("JUMP", stackJ);
            memToRegister(7);
        }

        argumentsTabIndex[0] = "-1";
        argumentsTabIndex[1] = "-1";
        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
    }
|   value DIVIDE value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);
        Identifier aI, bI;
        if(identifierStack.count(argumentsTabIndex[0]) > 0)
            aI = identifierStack.at(argumentsTabIndex[0]);
        if(identifierStack.count(argumentsTabIndex[1]) > 0)
            bI = identifierStack.at(argumentsTabIndex[1]);

        if(b.type == "NUM" && stoll(b.name) == 0) {
            setRegister("0");
        }
        else if(a.type == "NUM" && stoll(a.name) == 0) {
            setRegister("0");
        }
        else if(a.type == "NUM" && b.type == "NUM") {
            long long int val = stoll(a.name) / stoll(b.name);
            setRegister(to_string(val));
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else if(b.name == "2") {
            if(a.type == "PIDENTIFIER")
                memToRegister(a.memory);
            else if(a.type == "ARR" && aI.type == "NUM") {
                long long int addr = a.memory + stoll(aI.name) + 1;
                memToRegister(addr);
                removeIdentifier(aI.name);
            }
            else {
                memToRegister(a.memory);
                pushCommandOneArg("ADD", aI.memory);
                registerToMem(1);
                pushCommandOneArg("LOADI", 1);
            }
            pushCommand("SHR");
            removeIdentifier(b.name);
        }
        else {
            setRegister("0");
            registerToMem(5);
            registerToMem(8);
            long long int zeroJump = setToTempMem(b, bI, 7, 1, 1);
            long long int zeroJump2 = setToTempMem(a, aI, 6, 1, 1);

            pushCommand("INC");
            pushCommandOneArg("SUBSTRACT", 7);
            pushCommandOneArg("JZERO", codeStack.size()+38); //eeeeend
            pushCommandOneArg("JUMP", codeStack.size()+4);

            long long int jumpVal = codeStack.size();
            pushCommand("INC");
            pushCommandOneArg("SUBSTRACT", 7);
            pushCommandOneArg("JZERO", codeStack.size()+9);
            memToRegister(5);
            pushCommand("INC");
            registerToMem(5);
            memToRegister(7);
            pushCommand("SHL");
            registerToMem(7);
            memToRegister(6);
            pushCommandOneArg("JUMP", jumpVal);
            memToRegister(7);
            pushCommand("SHR");
            registerToMem(7);
            jumpVal = codeStack.size();
            memToRegister(5); //here is i
            pushCommandOneArg("JZERO", codeStack.size()+21); //to the end
            pushCommand("DEC");
            registerToMem(5);
            memToRegister(6);
            pushCommand("INC");
            pushCommandOneArg("SUBSTRACT", 7);
            pushCommandOneArg("JZERO", codeStack.size()+8); //to else
            pushCommand("DEC"); //need to think of value
            registerToMem(6);
            memToRegister(8);
            pushCommand("SHL");
            pushCommand("INC");
            registerToMem(8);
            pushCommandOneArg("JUMP", codeStack.size()+4); //to end of else
            memToRegister(8);   //here starts else
            pushCommand("SHL");
            registerToMem(8);
            memToRegister(7); //end of else
            pushCommand("SHR");
            registerToMem(7);
            pushCommandOneArg("JUMP", jumpVal); //to the i
            memToRegister(8); //end
            pushCommandOneArg("JUMP", codeStack.size()+2);
            addInt(zeroJump, codeStack.size());
            addInt(zeroJump2, codeStack.size());
            setRegister("0");
        }

        argumentsTabIndex[0] = "-1";
        argumentsTabIndex[1] = "-1";
        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
    }
|   value MOD value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);
        Identifier aI, bI;
        if(identifierStack.count(argumentsTabIndex[0]) > 0)
            aI = identifierStack.at(argumentsTabIndex[0]);
        if(identifierStack.count(argumentsTabIndex[1]) > 0)
            bI = identifierStack.at(argumentsTabIndex[1]);

        if(b.type == "NUM" && stoll(b.name) == 0) {
            setRegister("0");
        }
        else if(a.type == "NUM" && stoll(a.name) == 0) {
            setRegister("0");
        }
        else if(a.type == "NUM" && b.type == "NUM") {
            long long int val = stoll(a.name) % stoll(b.name);
            setRegister(to_string(val));
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else if(b.name == "2") {
            if(a.type == "PIDENTIFIER")
                memToRegister(a.memory);
            else if(a.type == "ARR" && aI.type == "NUM") {
                long long int addr = a.memory + stoll(aI.name) + 1;
                memToRegister(addr);
                removeIdentifier(aI.name);
            }
            else {
                memToRegister(a.memory);
                pushCommandOneArg("ADD", aI.memory);
                registerToMem(1);
                pushCommandOneArg("LOADI", 1);
            }
            pushCommandOneArg("JODD", codeStack.size() + 3);
            pushCommand("ZERO");
            pushCommandOneArg("JUMP", codeStack.size() + 3);
            pushCommand("ZERO");
            pushCommand("INC");

            removeIdentifier(b.name);
        }
        else {
            setRegister("0");
            registerToMem(5);
            long long int zeroJump = setToTempMem(b, bI, 7, 1, 1);
            long long int zeroJump2 = setToTempMem(a, aI, 6, 1, 1);

            pushCommand("INC");
            pushCommandOneArg("SUBSTRACT", 7);
            pushCommandOneArg("JZERO", codeStack.size()+30); //eeeeend
            pushCommandOneArg("JUMP", codeStack.size()+4);

            long long int jumpVal = codeStack.size();
            pushCommand("INC");
            pushCommandOneArg("SUBSTRACT", 7);
            pushCommandOneArg("JZERO", codeStack.size()+9);
            memToRegister(5);
            pushCommand("INC");
            registerToMem(5);
            memToRegister(7);
            pushCommand("SHL");
            registerToMem(7);
            memToRegister(6);
            pushCommandOneArg("JUMP", jumpVal);
            memToRegister(7);
            pushCommand("SHR");
            registerToMem(7);
            jumpVal = codeStack.size();
            memToRegister(5); //here is i
            pushCommandOneArg("JZERO", codeStack.size()+13); //to the end
            pushCommand("DEC");
            registerToMem(5);
            memToRegister(6);
            pushCommand("INC");
            pushCommandOneArg("SUBSTRACT", 7);
            pushCommandOneArg("JZERO", codeStack.size()+3); //to end of if
            pushCommand("DEC"); //need to think of value
            registerToMem(6);
            memToRegister(7); //end of if
            pushCommand("SHR");
            registerToMem(7);
            pushCommandOneArg("JUMP", jumpVal); //to the i
            memToRegister(6); //end
            pushCommandOneArg("JUMP", codeStack.size()+2);
            addInt(zeroJump, codeStack.size());
            addInt(zeroJump2, codeStack.size());
            setRegister("0");
        }

        argumentsTabIndex[0] = "-1";
        argumentsTabIndex[1] = "-1";
        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
    }
;

condition:
    value EQUAL value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(a.name) == stoll(b.name))
                setRegister("1");
            else
                setRegister("0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
            Jump jum;
            createJump(&jum, codeStack.size(), depth);
            jumpStack.push_back(jum);
            pushCommand("JZERO");
        }
        else {
            Identifier aI, bI;
            if(identifierStack.count(argumentsTabIndex[0]) > 0)
                aI = identifierStack.at(argumentsTabIndex[0]);
            if(identifierStack.count(argumentsTabIndex[1]) > 0)
                bI = identifierStack.at(argumentsTabIndex[1]);

            if(a.type != "ARR" && b.type != "ARR")
                sub(b, a, 0, 0);
            else
                subTab(b, a, bI, aI, 0, 0);

            pushCommandOneArg("JZERO", codeStack.size()+2);
            Jump j;
            createJump(&j, codeStack.size(), depth);
            jumpStack.push_back(j);
            pushCommand("JUMP");

            if(a.type != "ARR" && b.type != "ARR")
                sub(a, b, 0, 1);
            else
                subTab(a, b, aI, bI, 0, 1);

            pushCommandOneArg("JZERO", codeStack.size()+2);
            Jump jj;
            createJump(&jj, codeStack.size(), depth);
            jumpStack.push_back(jj);
            pushCommand("JUMP");
        }

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
        argumentsTabIndex[0] = "-1";
        argumentsTabIndex[1] = "-1";
    }
|   value NOTEQUAL value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(a.name) != stoll(b.name))
                setRegister("1");
            else
                setRegister("0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
            Jump jum;
            createJump(&jum, codeStack.size(), depth);
            jumpStack.push_back(jum);
            pushCommand("JZERO");
        }
        else {
            Identifier aI, bI;
            if(identifierStack.count(argumentsTabIndex[0]) > 0)
                aI = identifierStack.at(argumentsTabIndex[0]);
            if(identifierStack.count(argumentsTabIndex[1]) > 0)
                bI = identifierStack.at(argumentsTabIndex[1]);

            if(a.type != "ARR" && b.type != "ARR")
                sub(b, a, 0, 0);
            else
                subTab(b, a, bI, aI, 0, 0);

            pushCommandOneArg("JZERO", codeStack.size()+2);
            Jump j;
            createJump(&j, codeStack.size(), depth);
            jumpStack.push_back(j);
            pushCommand("JUMP");

            if(a.type != "ARR" && b.type != "ARR")
                sub(a, b, 0, 1);
            else
                subTab(a, b, aI, bI, 0, 1);

            addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size()+1);
            jumpStack.pop_back();

            Jump jj;
            createJump(&jj, codeStack.size(), depth);
            jumpStack.push_back(jj);
            pushCommand("JZERO");
        }

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
        argumentsTabIndex[0] = "-1";
        argumentsTabIndex[1] = "-1";
    }
|   value LEFTINEQUAL value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(a.name) < stoll(b.name))
                setRegister("1");
            else
                setRegister("0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else {
            if(a.type != "ARR" && b.type != "ARR")
                sub(b, a, 0, 1);
            else {
                Identifier aI, bI;
                if(identifierStack.count(argumentsTabIndex[0]) > 0)
                    aI = identifierStack.at(argumentsTabIndex[0]);
                if(identifierStack.count(argumentsTabIndex[1]) > 0)
                    bI = identifierStack.at(argumentsTabIndex[1]);
                subTab(b, a, bI, aI, 0, 1);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
        pushCommand("JZERO");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
    }
|   value RIGHTINEQUAL value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(b.name) < stoll(a.name))
                setRegister("1");
            else
                setRegister("0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else {
            if(a.type != "ARR" && b.type != "ARR")
                sub(a, b, 0, 1);
            else {
                Identifier aI, bI;
                if(identifierStack.count(argumentsTabIndex[0]) > 0)
                    aI = identifierStack.at(argumentsTabIndex[0]);
                if(identifierStack.count(argumentsTabIndex[1]) > 0)
                    bI = identifierStack.at(argumentsTabIndex[1]);
                subTab(a, b, aI, bI, 0, 1);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);;
        pushCommand("JZERO");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
    }
|   value LEFTINEQUALEQUAL value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(a.name) <= stoll(b.name))
                setRegister("1");
            else
                setRegister("0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else {
            if(a.type != "ARR" && b.type != "ARR")
                sub(b, a, 1, 1);
            else {
                Identifier aI, bI;
                if(identifierStack.count(argumentsTabIndex[0]) > 0)
                    aI = identifierStack.at(argumentsTabIndex[0]);
                if(identifierStack.count(argumentsTabIndex[1]) > 0)
                    bI = identifierStack.at(argumentsTabIndex[1]);
                subTab(b, a, bI, aI, 1, 1);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
        pushCommand("JZERO");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
    }
|   value RIGHTINEQUALEQUAL value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(a.name) >= stoll(b.name))
                setRegister("1");
            else
                setRegister("0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else {
            if(a.type != "ARR" && b.type != "ARR")
                sub(a, b, 1, 1);
            else {
                Identifier aI, bI;
                if(identifierStack.count(argumentsTabIndex[0]) > 0)
                    aI = identifierStack.at(argumentsTabIndex[0]);
                if(identifierStack.count(argumentsTabIndex[1]) > 0)
                    bI = identifierStack.at(argumentsTabIndex[1]);
                subTab(a, b, aI, bI, 1, 1);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
        pushCommand("JZERO");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
        argumentsTabIndex[0] = "-1";
        argumentsTabIndex[1] = "-1";
    }
;

value:
    NUM {
        if(assignFlag){
            cout << "Błąd linia: " << yylineno << " - Próba przypisania do stałej" << endl;
           	exit(1);
      	}
        Identifier s;
      	createIdentifier(&s, $1, 0, 0, "NUM");
        insertIdentifier($1, s);
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
        if(identifierStack.find($1) == identifierStack.end()) {
            cout << "Błąd linia: " << yylineno << " - Niezadeklarowana zmiennna " << $1 << endl;
            exit(1);
        }
        if(identifierStack.at($1).arraySize == 0) {
            if(!assignFlag){
                if(identifierStack.at($1).initialized == 0) {
                    cout << "Błąd linia: " << yylineno << " - Uzycie niezainicjalizowanej zmiennej " << $1 << endl;
                    exit(1);
                }
                if (expressionArguments[0] == "-1"){
                    expressionArguments[0] = $1;
                }
                else{
                    expressionArguments[1] = $1;
                }

            }
            else {
                assignTarget = identifierStack.at($1);
            }
        }
        else {
          cout << "Błąd linia: " << yylineno << " - Niepoprawne odwoanie do elementu tablicy " << $1 << endl;
          exit(1);
        }
    }
|   PIDENTIFIER LEFTBRACKET PIDENTIFIER RIGHTBRACKET {
        if(identifierStack.find($1) == identifierStack.end()) {
            cout << "Błąd linia: " << yylineno << " - Niezadeklarowana zmienna " << $1 << endl;
            exit(1);
        }
        if(identifierStack.find($3) == identifierStack.end()) {
            cout << "Błąd linia: " << yylineno << " - Niezadeklarowana zmienna " << $1 << endl;
            exit(1);
        }

        if(identifierStack.at($1).arraySize == 0) {
            cout << "Błąd linia: " << yylineno << " - Tablica nie ma zadeklarowanej dlugosci " << $1 << endl;
            exit(1);
        }
        else {
            if(identifierStack.at($3).initialized == 0) {
                cout << "Błąd linia: " << yylineno << " - Uzycie niezainicjalizowanej zmiennej " << $3 << endl;
                exit(1);
            }

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
                assignTarget = identifierStack.at($1);
                tabAssignTargetIndex = $3;
            }
        }
    }
|   PIDENTIFIER LEFTBRACKET NUM RIGHTBRACKET {
        if(identifierStack.find($1) == identifierStack.end()) {
            cout << "Błąd linia: " << yylineno << " - Niezadeklarowana zmienna " << $1 << endl;
            exit(1);
        }

        if(identifierStack.at($1).arraySize == 0) {
            cout << "Błąd linia: " << yylineno << " - Tablica nie ma zadeklarowanej dlugosci" << $1 << endl;
            exit(1);
        }
        else {
            Identifier s;
            createIdentifier(&s, $3, 0, 0, "NUM");
            insertIdentifier($3, s);

            if(!assignFlag){
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
                assignTarget = identifierStack.at($1);
                tabAssignTargetIndex = $3;
            }
        }
    }
;

%%

void createIdentifier(Identifier *s, string name, long long int isLocal,
    long long int isArray, string type){
    s->name = name;
    s->memory = memCounter;
    s->type = type;
    s->initialized = 0;
    if(isLocal){
    	s->local = 1;
    }
    else{
    	s->local = 0;
    }
    if(isArray){
      s->arraySize = isArray;
    }
    else{
      s->arraySize = 0;
    }
}

void createJump(Jump *j, long long int stack, long long int depth) {
    j->placeInStack = stack;
    j->depth = depth;
}

long long int setToTempMem(Identifier a, Identifier aI, long long int tempMem, int isJZERO, int isRemoval) {
    long long int memory = 0;
    if(a.type == "NUM") {
        setRegister(a.name);
        if(isJZERO) {
            memory = codeStack.size();
            pushCommand("JZERO");
        }
        registerToMem(tempMem);
        if(isRemoval)
            removeIdentifier(a.name);
    }
    else if(a.type == "PIDENTIFIER") {
        memToRegister(a.memory);
        if(isJZERO) {
            memory = codeStack.size();
            pushCommand("JZERO"); //JZERO END
        }
        registerToMem(tempMem);
    }
    else if(a.type == "ARR" && aI.type == "NUM") {
        long long int addr = a.memory + stoll(aI.name) + 1;
        memToRegister(addr);
        if(isJZERO) {
            memory = codeStack.size();
            pushCommand("JZERO"); //JZERO END
        }
        registerToMem(tempMem);
        if(isRemoval)
            removeIdentifier(aI.name);
    }
    else if(a.type == "ARR" && aI.type == "PIDENTIFIER") {
        memToRegister(a.memory);
        pushCommandOneArg("ADD", aI.memory);
        registerToMem(tempMem);
        pushCommandOneArg("LOADI", tempMem);
        if(isJZERO) {
            memory = codeStack.size();
            pushCommand("JZERO"); //JZERO END
        }
        registerToMem(tempMem);
    }
    return memory;
}

void add(Identifier a, Identifier b) {
    if(a.type == "NUM" && b.type == "NUM") {
        long long int val = stoll(a.name) + stoll(b.name);
        setRegister(to_string(val));
        removeIdentifier(a.name);
        removeIdentifier(b.name);
    }
    else if(a.type == "NUM" && b.type == "PIDENTIFIER") {
        //trying to opt
        if(stoll(a.name) < 8) {
            memToRegister(b.memory);
            for(int i=0; i < stoll(a.name); i++) {
                pushCommand("INC");
            }
            removeIdentifier(a.name);
        }
        else {
            setRegister(a.name);
            pushCommandOneArg("ADD", b.memory);
            removeIdentifier(a.name);
        }
    }
    else if(a.type == "PIDENTIFIER" && b.type == "NUM") {
        //trying to opt
        if(stoll(b.name) < 8) {
            memToRegister(a.memory);
            for(int i=0; i < stoll(b.name); i++) {
                pushCommand("INC");
            }
            removeIdentifier(b.name);
        }
        else {
            setRegister(b.name);
            pushCommandOneArg("ADD", a.memory);
            removeIdentifier(b.name);
        }
    }
    else if(a.type == "PIDENTIFIER" && b.type == "PIDENTIFIER") {
        if(a.name == b.name) {
            memToRegister(a.memory);
            pushCommand("SHL");
        }
        else {
            memToRegister(a.memory);
            pushCommandOneArg("ADD", b.memory);
        }
    }
}

void addTab(Identifier a, Identifier b, Identifier aIndex, Identifier bIndex) {
    if(a.type == "NUM" && b.type == "ARR") {
        if(bIndex.type == "NUM") {
            long long int addr = b.memory + stoll(bIndex.name) + 1;

            //trying to opt
            if(stoll(a.name) < 8) {
                memToRegister(addr);
                for(int i=0; i < stoll(a.name); i++) {
                    pushCommand("INC");
                }
            }
            else {
                setRegister(a.name);
                pushCommandOneArg("ADD", addr);
            }

            removeIdentifier(a.name);
            removeIdentifier(bIndex.name);
        }
        else if(bIndex.type == "PIDENTIFIER") {
            memToRegister(b.memory);
            pushCommandOneArg("ADD", bIndex.memory);
            registerToMem(1);
            //trying to opt
            if(stoll(a.name) < 8) {
                pushCommandOneArg("LOADI", 1);
                for(int i=0; i < stoll(a.name); i++) {
                    pushCommand("INC");
                }
            }
            else {
                setRegister(a.name);
                pushCommandOneArg("ADDI", 1);
            }
            removeIdentifier(a.name);
        }
    }
    else if(a.type == "ARR" && b.type == "NUM") {
        if(aIndex.type == "NUM") {
            long long int addr = a.memory + stoll(aIndex.name) + 1;
            //trying to opt
            if(stoll(b.name) < 8) {
                memToRegister(addr);
                for(int i=0; i < stoll(b.name); i++) {
                    pushCommand("INC");
                }
            }
            else {
                setRegister(b.name);
                pushCommandOneArg("ADD", addr);
            }
            removeIdentifier(b.name);
            removeIdentifier(aIndex.name);
        }
        else if(aIndex.type == "PIDENTIFIER") {
            memToRegister(a.memory);
            pushCommandOneArg("ADD", aIndex.memory);
            registerToMem(1);
            //trying to opt
            if(stoll(b.name) < 8) {
                pushCommandOneArg("LOADI", 1);
                for(int i=0; i < stoll(b.name); i++) {
                    pushCommand("INC");
                }
            }
            else {
                setRegister(b.name);
                pushCommandOneArg("ADDI", 1);
            }
            removeIdentifier(b.name);
        }
    }
    else if(a.type == "PIDENTIFIER" && b.type == "ARR") {
        if(bIndex.type == "NUM") {
            long long int addr = b.memory + stoll(bIndex.name) + 1;
            memToRegister(a.memory);
            pushCommandOneArg("ADD", addr);
            removeIdentifier(bIndex.name);
        }
        else if(bIndex.type == "PIDENTIFIER") {
            memToRegister(b.memory);
            pushCommandOneArg("ADD", bIndex.memory);
            registerToMem(1);
            memToRegister(a.memory);
            pushCommandOneArg("ADDI", 1);
        }
    }
    else if(a.type == "ARR" && b.type == "PIDENTIFIER") {
        if(aIndex.type == "NUM") {
            long long int addr = a.memory + stoll(aIndex.name) + 1;
            memToRegister(b.memory);
            pushCommandOneArg("ADD", addr);
            removeIdentifier(aIndex.name);
        }
        else if(aIndex.type == "PIDENTIFIER") {
            memToRegister(a.memory);
            pushCommandOneArg("ADD", aIndex.memory);
            registerToMem(1);
            memToRegister(b.memory);
            pushCommandOneArg("ADDI", 1);
        }
    }
    else if(a.type == "ARR" && b.type == "ARR") {
        if(aIndex.type == "NUM" && bIndex.type == "NUM") {
            long long int addrA = a.memory + stoll(aIndex.name) + 1;
            long long int addrB = b.memory + stoll(bIndex.name) + 1;
            if(a.name == b.name && addrA == addrB) {
                memToRegister(addrA);
                pushCommand("SHL");
            }
            else {
                memToRegister(addrA);
                pushCommandOneArg("ADD", addrB);
            }
            removeIdentifier(aIndex.name);
            removeIdentifier(bIndex.name);
        }
        else if(aIndex.type == "NUM" && bIndex.type == "PIDENTIFIER") {
            long long int addrA = a.memory + stoll(aIndex.name) + 1;
            memToRegister(b.memory);
            pushCommandOneArg("ADD", bIndex.memory);
            registerToMem(1);
            memToRegister(addrA);
            pushCommandOneArg("ADDI", 1);
            removeIdentifier(aIndex.name);
        }
        else if(aIndex.type == "PIDENTIFIER" && bIndex.type == "NUM") {
            long long int addrB = b.memory + stoll(bIndex.name) + 1;
            memToRegister(a.memory);
            pushCommandOneArg("ADD", aIndex.memory);
            registerToMem(1);
            memToRegister(addrB);
            pushCommandOneArg("ADDI", 1);
            removeIdentifier(bIndex.name);
        }
        else if(aIndex.type == "PIDENTIFIER" && bIndex.type == "PIDENTIFIER") {
            if(a.name == b.name && aIndex.name == bIndex.name) {
                memToRegister(a.memory);
                pushCommandOneArg("ADD", aIndex.memory);
                registerToMem(1);
                pushCommandOneArg("LOADI", 1);
                pushCommand("SHL");
            }
            else {
                memToRegister(a.memory);
                pushCommandOneArg("ADD", aIndex.memory);
                registerToMem(1);
                memToRegister(b.memory);
                pushCommandOneArg("ADD", bIndex.memory);
                registerToMem(0);
                pushCommandOneArg("LOADI", 1);
                pushCommandOneArg("ADDI", 0);
            }
        }
    }
}

void sub(Identifier a, Identifier b, int isINC, int isRemoval) {
    if(a.type == "NUM" && b.type == "NUM") {
        long long int val = max(stoll(a.name) + isINC - stoll(b.name), (long long int) 0);
        setRegister(to_string(val));
        if(isRemoval) {
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
    }
    else if(a.type == "NUM" && b.type == "PIDENTIFIER") {
        setRegister(to_string(stoll(a.name) + isINC));
        pushCommandOneArg("SUBSTRACT", b.memory);
        if(isRemoval)
            removeIdentifier(a.name);
    }
    else if(a.type == "PIDENTIFIER" && b.type == "NUM") {
        //this is harder -- what is going on here -- i feel lost in my own code
        //just think I have made too many options... ok let's opt
        if(stoll(b.name) < 28) {
            memToRegister(a.memory);
            if(stoll(b.name)==0 && isINC)
                pushCommand("INC");
            else {
                for(int i=0; i < stoll(b.name) - isINC; i++) {
                    pushCommand("DEC");
                }
            }
        }
        else {
            setRegister(b.name);
            registerToMem(3);
            memToRegister(a.memory);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUBSTRACT", 3);
        }
        if(isRemoval)
            removeIdentifier(b.name);
    }
    else if(a.type == "PIDENTIFIER" && b.type == "PIDENTIFIER") {
        if(a.name == b.name) {
            pushCommand("ZERO");
            if(isINC)
                pushCommand("INC");
        }
        else {
            memToRegister(a.memory);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUBSTRACT", b.memory);
        }
    }
}

void subTab(Identifier a, Identifier b, Identifier aIndex, Identifier bIndex, int isINC, int isRemoval) {
    if(a.type == "NUM" && b.type == "ARR") {
        if(bIndex.type == "NUM") {
            long long int addr = b.memory + stoll(bIndex.name) + 1;
            setRegister(to_string(stoll(a.name) + isINC));
            pushCommandOneArg("SUBSTRACT", addr);
            if(isRemoval) {
                removeIdentifier(a.name);
                removeIdentifier(bIndex.name);
            }
        }
        else if(bIndex.type == "PIDENTIFIER") {
            memToRegister(b.memory);
            pushCommandOneArg("ADD", bIndex.memory);
            registerToMem(1);
            setRegister(to_string(stoll(a.name) + isINC));
            pushCommandOneArg("SUBI", 1);
            if(isRemoval)
                removeIdentifier(a.name);
        }
    }
    else if(a.type == "ARR" && b.type == "NUM") {
        if(aIndex.type == "NUM") {
            long long int addr = a.memory + stoll(aIndex.name) + 1;
            //this is harder -- what is going on here -- i feel lost in my own code
            //just think I have made too many options... ok let's opt
            if(stoll(b.name) < 28) {
                memToRegister(addr);
                if(stoll(b.name)==0 && isINC)
                    pushCommand("INC");
                else {
                    for(int i=0; i < stoll(b.name) - isINC; i++) {
                        pushCommand("DEC");
                    }
                }
            }
            else {
                setRegister(b.name);
                registerToMem(3);
                memToRegister(addr);
                if(isINC)
                    pushCommand("INC");
                pushCommandOneArg("SUBSTRACT", 3);
            }
            if(isRemoval) {
                removeIdentifier(b.name);
                removeIdentifier(aIndex.name);
            }
        }
        else if(aIndex.type == "PIDENTIFIER") {
            //this is harder -- what is going on here -- i feel lost in my own code
            //just think I have made too many options... ok let's opt
            if(stoll(b.name) < 28) {
                memToRegister(a.memory);
                pushCommandOneArg("ADD", aIndex.memory);
                registerToMem(1);
                pushCommandOneArg("LOADI", 1);

                if(stoll(b.name)==0 && isINC)
                    pushCommand("INC");
                else {
                    for(int i=0; i < stoll(b.name) - isINC; i++) {
                        pushCommand("DEC");
                    }
                }
            }
            else {
                setRegister(b.name);
                registerToMem(3);
                memToRegister(a.memory);
                pushCommandOneArg("ADD", aIndex.memory);
                registerToMem(1);
                pushCommandOneArg("LOADI", 1);
                if(isINC)
                    pushCommand("INC");
                pushCommandOneArg("SUBSTRACT", 3);
            }
            if(isRemoval)
                removeIdentifier(b.name);
        }
    }
    else if(a.type == "PIDENTIFIER" && b.type == "ARR") {
        if(bIndex.type == "NUM") {
            long long int addr = b.memory + stoll(bIndex.name) + 1;
            memToRegister(a.memory);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUBSTRACT", addr);
            if(isRemoval)
                removeIdentifier(bIndex.name);
        }
        else if(bIndex.type == "PIDENTIFIER") {
            memToRegister(b.memory);
            pushCommandOneArg("ADD", bIndex.memory);
            registerToMem(1);
            memToRegister(a.memory);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUBI", 1);
        }
    }
    else if(a.type == "ARR" && b.type == "PIDENTIFIER") {
        if(aIndex.type == "NUM") {
            long long int addr = a.memory + stoll(aIndex.name) + 1;
            memToRegister(addr);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUBSTRACT", b.memory);
            if(isRemoval)
                removeIdentifier(aIndex.name);
        }
        else if(aIndex.type == "PIDENTIFIER") {
            memToRegister(a.memory);
            pushCommandOneArg("ADD", aIndex.memory);
            registerToMem(1);
            pushCommandOneArg("LOADI", 1);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUBSTRACT", b.memory);
        }
    }
    else if(a.type == "ARR" && b.type == "ARR") {
        if(aIndex.type == "NUM" && bIndex.type == "NUM") {
            long long int addrA = a.memory + stoll(aIndex.name) + 1;
            long long int addrB = b.memory + stoll(bIndex.name) + 1;
            if(a.name == b.name && addrA == addrB) {
                pushCommand("ZERO");
                if(isINC)
                    pushCommand("INC");
            }
            else {
                memToRegister(addrA);
                if(isINC)
                    pushCommand("INC");
                pushCommandOneArg("SUBSTRACT", addrB);
            }
            if(isRemoval) {
                removeIdentifier(aIndex.name);
                removeIdentifier(bIndex.name);
            }
        }
        else if(aIndex.type == "NUM" && bIndex.type == "PIDENTIFIER") {
            long long int addrA = a.memory + stoll(aIndex.name) + 1;
            memToRegister(b.memory);
            pushCommandOneArg("ADD", bIndex.memory);
            registerToMem(1);
            memToRegister(addrA);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUBI", 1);
            if(isRemoval)
                removeIdentifier(aIndex.name);
        }
        else if(aIndex.type == "PIDENTIFIER" && bIndex.type == "NUM") {
            long long int addrB = b.memory + stoll(bIndex.name) + 1;
            memToRegister(a.memory);
            pushCommandOneArg("ADD", aIndex.memory);
            registerToMem(1);
            pushCommandOneArg("LOADI", 1);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUBSTRACT", addrB);
            if(isRemoval)
                removeIdentifier(bIndex.name);
        }
        else if(aIndex.type == "PIDENTIFIER" && bIndex.type == "PIDENTIFIER") {
            if(a.name == b.name && aIndex.name == bIndex.name) {
                pushCommand("ZERO");
                if(isINC)
                    pushCommand("INC");
            }
            else {
                memToRegister(a.memory);
                pushCommandOneArg("ADD", aIndex.memory);
                registerToMem(1);
                memToRegister(b.memory);
                pushCommandOneArg("ADD", bIndex.memory);
                registerToMem(0);
                pushCommandOneArg("LOADI", 1);
                if(isINC)
                    pushCommand("INC");
                pushCommandOneArg("SUBI", 0);
            }
        }
    }
}

void addInt(long long int command, long long int val) {
    codeStack.at(command) = codeStack.at(command) + " " + to_string(val);
}

void setRegister(string number) {
    long long int n = stoll(number);
	/*if (n == registerValue) {
		return;
	}*/
    string bin = decToBin(n);
	long long int limit = bin.size();
    zeroRegister();
	for(long long int i = 0; i < limit; ++i){
		if(bin[i] == '1'){
			pushCommand("INC");
			/*registerValue++;*/
		}
		if(i < (limit - 1)){
	        pushCommand("SHL");
	        /*registerValue *= 2;*/
		}
	}
}

void zeroRegister() {
	/*if(registerValue != 0){*/
		pushCommand("ZERO");
		/*registerValue = 0;*/
	/*}*/
}

void memToRegister(long long int memory) {
	pushCommandOneArg("LOAD", memory);
	/*registerValue = -1;*/
}

string decToBin(long long int n) {
    string r;
    while(n!=0) {r=(n%2==0 ?"0":"1")+r; n/=2;}
    return r;
}

void registerToMem(long long int memory) {
	pushCommandOneArg("STORE", memory);
}

void insertIdentifier(string key, Identifier i) {
    if(identifierStack.count(key) == 0) {
        identifierStack.insert(make_pair(key, i));
        identifierStack.at(key).counter = 0;
        memCounter++;
    }
    else {
        identifierStack.at(key).counter = identifierStack.at(key).counter+1;
    }
    /*cout << "Add: " << key << " " << memCounter-1 << endl;*/
}

void removeIdentifier(string key) {
    if(identifierStack.count(key) > 0) {
        if(identifierStack.at(key).counter > 0) {
            identifierStack.at(key).counter = identifierStack.at(key).counter-1;
        }
        else {
            identifierStack.erase(key);
            memCounter--;
        }
    }
    /*cout << "Remove: " << key << endl;*/
}

void pushCommand(string str) {
    /*cout << str << endl;*/
    codeStack.push_back(str);
}

void pushCommandOneArg(string str, long long int num) {
    /*cout << str << endl;*/
    string temp = str + " " + to_string(num);
    codeStack.push_back(temp);
}

void printCode(string outFileName) {
    ofstream out_code(outFileName);
	long long int i;
	for(i = 0; i < codeStack.size(); i++)
        out_code << codeStack.at(i) << endl;
}

void printCodeStd() {
	long long int i;
	for(i = 0; i < codeStack.size(); i++)
        cout << codeStack.at(i) << endl;
}

void parser(long long int argv, char* argc[]) {
	assignFlag = 1;
	memCounter = 12;
    /*registerValue = -1;*/
	writeFlag = 0;
    depth = 0;

	yyparse();

    string file = "";
    if(argv < 2)
        /*file = "out";*/
        printCodeStd();
    else {
        file = argc[1];
        printCode(file);
    }
}

int main(int argv, char* argc[]){
	parser(argv, argc);
	return 0;
}

int yyerror(string str){
    cout << "Błąd [okolice linii " << yylineno << \
    "]: " << str << endl;
	/*return 1;*/
    exit(1);
}
