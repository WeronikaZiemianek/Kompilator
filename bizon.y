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

  typedef struct {
    string name;
    // NUMBER/IDENTIFIER/ARRAY
    string type;
    long long int isLocal;
    int isInitialized;
    int counter;
    int move;
    long long int arraySize;
    long long int memory;
  } Idef;

  map<string, Idef> idefStack;
  vector<string> asmStack;

  int flagAssign;
  int flagWrite;

  Idef assignArg;
  string assignArgTabIndex = "-1";
  string expressionArgs[2] = {"-1", "-1"};
  string expArgsTabIndex[2] = {"-1", "-1"};

  long long int memCounter;

  void printAsm(string outFileName);
  void printAsmStack();

  void createIdef(Idef *idef, string name, string type, long long int isLocal, long long int arraySize, long long int move);
  void insertIdef(string key, Idef i);
  void removeIdef(string key);

  void setReg(string number, long long int reg);
  void zeroReg(long long int reg);
  void binToAsmStack(long long int reg, string bin);
  void regToMem(long long int reg);
  void memToReg(long long int memory);
  void pushCmd(string s);

  string decToBin(long long int n);
  string to_ascii(long long int value);
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
      createIdef(&idef, $2, "IDENTIFIER", 0, 0, 0);
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
      createIdef(&idef, $2, "ARRAY", 0, arraySize, atoll($4));
      insertIdef($2, idef);
      memCounter += arraySize;
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
identifier ASSIGN {
  flagAssign = 0;
}
expression SEMICOLON {
  if(assignArg.type == "ARRAY") {
    Idef idef = idefStack.at(assignArgTabIndex);
    if(idef.type == "NUMBER") {
      long long int arrayEl = assignArg.memory + stoll(idef.name) - assignArg.move + 1;
      setReg(to_string(arrayEl), 1);
      regToMem(8);
      removeIdef(idef.name);
    }
    else {
      setReg(to_string(idef.memory),1);
      memToReg(2);
      long long int indexFix = assignArg.memory - assignArg.move + 1;
      setReg(to_string(indexFix),3);
      pushCmd("ADD B C");
      pushCmd("COPY A B");
      regToMem(8);
      //removeIdef(idef.name);
    }
  }
  else if(assignArg.isLocal == 0) {
    setReg(to_string(assignArg.memory), 1);
    regToMem(8);
  }
  else {
    cout << "Błąd: linia " << yylineno << " - modyfikacji iteratora pętli " << $<str>1 << "\n";
    exit(1);
  }
  idefStack.at(assignArg.name).isInitialized = 1;
  flagAssign = 1;
}
| IF condition THEN commands ELSE commands ENDIF {}
| IF condition THEN commands ENDIF {}
| WHILE condition DO commands ENDWHILE {}
| DO commands WHILE condition ENDDO {}
| FOR PIDENTIFIER FROM value TO value DO commands ENDFOR {}
| FOR PIDENTIFIER FROM value DOWNTO value DO commands ENDFOR {}
| READ identifier SEMICOLON {}
|  WRITE {
        flagAssign = 0;
        flagWrite = 1;
    } value SEMICOLON {
        Idef idef = idefStack.at(expressionArgs[0]);

        if(idef.type == "NUMBER") {
            setReg(idef.name,8);
        }
        else if (idef.type == "IDENTIFIER") {
            setReg(to_string(idef.memory),1);
            memToReg(8);
        }
        else {
            Idef i = idefStack.at(expArgsTabIndex[0]);
            if(i.type == "NUMBER") {
                long long int arrayEl = idef.memory + stoll(i.name) - idef.move + 1;
                setReg(to_string(arrayEl), 1);
                memToReg(8);
            }
            else {
                setReg(to_string(i.memory),1);
                memToReg(2);
                long long int indexFix = idef.memory - idef.move + 1;
                setReg(to_string(indexFix),3);
                pushCmd("ADD B C");
                pushCmd("COPY A B");
                memToReg(8);
            }
        }
        pushCmd("PUT H");
        flagAssign = 1;
        flagWrite = 0;
        expressionArgs[0] = "-1";
        expArgsTabIndex[0] = "-1";
    }
;

expression:
value {
  Idef idef = idefStack.at(expressionArgs[0]);
  if(idef.type == "NUMBER") {
    setReg(idef.name, 8);
    removeIdef(idef.name);
  }
  else if(idef.type == "IDENTIFIER") {
    setReg(to_string(idef.memory), 1);
    memToReg(8);
  }
  else{
    Idef i = idefStack.at(expArgsTabIndex[0]);
    if(i.type == "NUMBER"){
      long long int arrayEl = idef.memory + stoll(i.name) - idef.move + 1;
      setReg(to_string(arrayEl), 1);
      memToReg(8);
      removeIdef(i.name);
    }
    else{
       setReg(to_string(i.memory),1);
       memToReg(2);
       long long int indexFix = idef.memory - idef.move + 1;
       setReg(to_string(indexFix),3);
       pushCmd("ADD B C");
       pushCmd("COPY A B");
       memToReg(8);
       //removeIdef(i.name);
    }
  }
  if (!flagWrite) {
      expressionArgs[0] = "-1";
      expArgsTabIndex[0] = "-1";
  }
}
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
    createIdef(&idef, $1, "NUMBER", 0, 0, 0);
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
PIDENTIFIER {
    if(idefStack.find($1) == idefStack.end()){
      cout << "Błąd linia: " << yylineno << " - Zmienna " << $<str>1 << " nie zostala zadeklarowana." << "\n";
      exit(1);
    }
    if(idefStack.at($1).arraySize == 0){
      if(!flagAssign){
        if(idefStack.at($1).isInitialized ==0){
	         cout << "Błąd linia: " << yylineno << " - Zmienna " << $<str>1 << " nie zostala zainicjalizowana." << "\n";
	         exit(1);
	        }
	      if(expressionArgs[0] == "-1"){
	         expressionArgs[0] = $1;
	        }
	      else {
	         expressionArgs[1] = $1;
	        }
      }
      else {
        assignArg = idefStack.at($1);
      }
    }
    else {
	     cout << "Błąd linia: " << yylineno << " - Brak podanego odwoania do elementu tablicy " << $<str>1 << "\n";
	     exit(1);
    }
}
| PIDENTIFIER LEFTBRACKET PIDENTIFIER RIGHTBRACKET {
    if(idefStack.find($1) == idefStack.end()){
      cout << "Błąd linia: " << yylineno << " - Zmienna " << $<str>1 << " nie zostala zadeklarowana." << "\n";
      exit(1);
    }
    if(idefStack.find($3) == idefStack.end()){
      cout << "Błąd linia: " << yylineno << " - Zmienna " << $<str>3 << " nie zostala zadeklarowana." << "\n";
      exit(1);
    }
    if(idefStack.at($1).arraySize == 0){
      cout << "Błąd linia: " << yylineno << " - Zmienna " << $<str>1 << " nie jest tablica." << "\n";
      exit(1);
    }
    else{
      if(idefStack.at($3).isInitialized == 0){
	       cout << "Błąd linia: " << yylineno << " - Zmienna " << $<str>3 << " nie zostala zainicjalizowana." << "\n";
	       exit(1);
      }
      if(!flagAssign){
        if(expressionArgs[0] == "-1"){
          expressionArgs[0] = $1;
          expArgsTabIndex[0] = $3;
        }
        else{
          expressionArgs[1] = $1;
	        expArgsTabIndex[1] = $3;
        }
      }
      else{
        assignArg = idefStack.at($1);
        assignArgTabIndex = $3;
      }
    }
}
| PIDENTIFIER LEFTBRACKET NUM RIGHTBRACKET {
    if(idefStack.find($1) == idefStack.end()){
      cout << "Błąd linia: " << yylineno << " - Zmienna " << $<str>1 << " nie zostala zadeklarowana." << "\n";
      exit(1);
    }
    if(idefStack.at($1).arraySize == 0){
      cout << "Błąd linia: " << yylineno << " - Zmienna " << $<str>1 << " nie jest typu tablicowego." << "\n";
      exit(1);
    }
    else{
      Idef idef;
      createIdef(&idef, $3, "NUMBER", 0, 0, assignArg.move);
      insertIdef($3, idef);

      if(!flagAssign){
        if(expressionArgs[0] == "-1"){
          expressionArgs[0] = $1;
          expArgsTabIndex[0] = $3;
        }
        else{
          expressionArgs[1] = $1;
          expArgsTabIndex[1] = $3;
        }
      }
      else{
        assignArg = idefStack.at($1);
        assignArgTabIndex = $3;
      }
    }
}
;

%%
void createIdef(Idef *idef, string name, string type, long long int isLocal, long long int arraySize, long long int move){
    idef->name = name;
    idef->memory = memCounter;
    idef->type = type;
    idef->move = move;
    idef->isLocal = isLocal ? 1 : 0;
    idef->isInitialized = 0;
    idef->arraySize = arraySize;
}

void insertIdef(string key, Idef idef) {
    if(idefStack.count(key) == 0) {
        idefStack.insert(make_pair(key, idef));
        idefStack.at(key).counter = 0;
        memCounter++;
    }
    else {
        idefStack.at(key).counter +=1;
    }
}

void removeIdef(string key) {
    if(idefStack.count(key) > 0) {
        if(idefStack.at(key).counter > 0) {
            idefStack.at(key).counter -= 1;
        }
        else {
            idefStack.erase(key);
        }
    }
}

void setReg(string number, long long int reg) {
  long long int n = stoll(number);
	string bin = decToBin(n);
  zeroReg(reg);
  binToAsmStack(reg, bin);
}

void zeroReg(long long int reg) {
    pushCmd("SUB " + to_ascii(reg) + " " + to_ascii(reg));
}

void binToAsmStack(long long int reg, string bin) {
  long long int maxSize = bin.size();
  for(long long int i = 0; i <= maxSize; i++){
		if(bin[i] == '1')
			pushCmd("INC " + to_ascii(reg));
		if(i < (maxSize - 1))
      pushCmd("ADD " + to_ascii(reg) + " " + to_ascii(reg));
	}
}

void regToMem(long long int reg) {
	pushCmd("STORE " + to_ascii(reg));
}

void memToReg(long long int memory) {
	pushCmd("LOAD " + to_ascii(memory));
}

void pushCmd(string s) {
    asmStack.push_back(s);
}

string decToBin(long long int n) {
    string r;
    while(n!=0) {r=(n%2==0 ?"0":"1")+r; n/=2;}
    return r;
}

void printAsm(string outFileName) {
  ofstream out_code(outFileName);
	for(long long int i = 0; i < asmStack.size(); i++)
        out_code << asmStack.at(i) << endl;
}


void printAsmStack(){
	for(long long int i = 0; i < asmStack.size(); i++)
        cout << asmStack.at(i) << endl;
}

int main(int argv, char* argc[]){
  flagAssign = 1;
  flagWrite = 0;
  memCounter = 1;

  yyparse();

  string file = "";
    if(argv < 2)
        printAsmStack();
    else {
        file = argc[1];
        printAsm(file);
    }
	return 0;
}

int yyerror(string str){
    cout << "Błąd: linia " << yylineno << " "<< str << "\n";
    exit(1);
}

string to_ascii(long long int value) {
  switch( value )
   {
   case 1:
       return "A";
   case 2:
       return "B";
   case 3:
       return "C";
   case 4:
       return "D";
   case 5:
       return "E";
   case 6:
       return "F";
   case 7:
       return "G";
   case 8:
       return "H";
   }
   return 0;
}
