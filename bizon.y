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
    long long int mem;
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
  long long int firstFreeReg();
  void regToMem(long long int reg);
  void memToReg(long long int mem);
  void pushCmd(string s);
  string decToBin(long long int n);
  string to_ascii(long long int value);

  void add(Idef a, Idef b);
  void addTab(Idef a, Idef b, Idef aIndex, Idef bIndex);
  void sub(Idef a, Idef b);
  void subTab(Idef a, Idef b, Idef aIndex, Idef bIndex);

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
      createIdef(&idef, $2, "ARR", 0, arraySize, atoll($4));
      insertIdef($2, idef);
      memCounter += arraySize;
      setReg(to_string(idef.mem+1),idef.mem);
      regToMem(idef.mem);
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
      long long int arrayEl = assignArg.mem + stoll(idef.name) + 1;
      regToMem(arrayEl);
      removeIdef(idef.name);
    }
    else {
      regToMem(0);
      memToReg(assignArg.mem);
      pushCmd("ADD " + to_ascii(idef.mem));
      regToMem(2);
      memToReg(0);
      pushCmd("STORETAB 2");
    }
  }
  else if(assignArg.isLocal == 0) {
    regToMem(assignArg.mem);
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
        Idef ide = idefStack.at(expressionArgs[0]);

        if(ide.type == "NUMBER") {
            setReg(ide.name, assignArg.mem);
            removeIdef(ide.name);
        }
        else if (ide.type == "IDENTIFIER") {
            memToReg(ide.mem);
        }
        else {
            Idef index = idefStack.at(expArgsTabIndex[0]);
            if(index.type == "NUMBER") {
                long long int tabElMem = ide.mem + stoll(index.name) + 1;
                memToReg(tabElMem);
                removeIdef(index.name);
            }
            else {
                memToReg(ide.mem);
                pushCmd("ADD " + to_ascii(ide.mem) + " " + to_ascii(index.mem));
                pushCmd("STORE 0");
                pushCmd("LOADTAB 0");
            }
        }
        pushCmd("PUT " + to_ascii(assignArg.mem));
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
    setReg(idef.name, assignArg.mem);
    removeIdef(idef.name);
  }
  else if(idef.type == "IDENTIFIER") {
    memToReg(idef.mem);
  }
  else{
    Idef i = idefStack.at(expArgsTabIndex[0]);
    if(i.type == "NUMBER"){
      long long int memElement = idef.mem + stoll(i.name) + 1;
      memToReg(memElement);
      removeIdef(i.name);
    }
    else{
       memToReg(idef.mem);
       pushCmd("ADD " + to_ascii(i.mem));
       pushCmd("STORE 0");
       pushCmd("LOADTAB 0");
    }
  }
  if (!flagWrite) {
      expressionArgs[0] = "-1";
      expArgsTabIndex[0] = "-1";
  }
}
| value ADD value {
  Idef a = idefStack.at(expressionArgs[0]);
  Idef b = idefStack.at(expressionArgs[1]);
  if(a.type != "ARRAY" && b.type != "ARRAY"){
    add(a, b);
  }
  else {
    Idef aIndex, bIndex;
    if(idefStack.count(expArgsTabIndex[0]) > 0)
        aIndex = idefStack.at(expArgsTabIndex[0]);
    if(idefStack.count(expArgsTabIndex[1]) > 0)
        bIndex = idefStack.at(expArgsTabIndex[1]);
    addTab(a, b, aIndex, bIndex);
    expArgsTabIndex[0] = "-1";
    expArgsTabIndex[1] = "-1";
  }
  expressionArgs[0] = "-1";
  expressionArgs[1] = "-1";
}
| value SUBSTRACT value {
  Idef a = idefStack.at(expressionArgs[0]);
  Idef b = idefStack.at(expressionArgs[1]);
  if(a.type != "ARRAY" && b.type != "ARRAY"){
    sub(a, b);
  }
  else {
    Idef aIndex, bIndex;
    if(idefStack.count(expArgsTabIndex[0]) > 0)
        aIndex = idefStack.at(expArgsTabIndex[0]);
    if(idefStack.count(expArgsTabIndex[1]) > 0)
        bIndex = idefStack.at(expArgsTabIndex[1]);
    subTab(a, b, aIndex, bIndex);
    expArgsTabIndex[0] = "-1";
    expArgsTabIndex[1] = "-1";
  }
  expressionArgs[0] = "-1";
  expressionArgs[1] = "-1";
}
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
      createIdef(&idef, $3, "NUMBER", 0, 0, 0);
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
    idef->mem = memCounter;
    idef->type = type;
    idef->move = move;

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
        memCounter++;
    }
    else {
        idefStack.at(key).counter +=1;;
    }
}

void removeIdef(string key) {
    if(idefStack.count(key) > 0) {
        if(idefStack.at(key).counter > 0) {
            idefStack.at(key).counter -= 1;
        }
        else {
            idefStack.erase(key);
            memCounter--;
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
		if(bin[i] == '1'){
			pushCmd("INC " + to_ascii(reg));
		}
		if(i < (maxSize - 1)){
          pushCmd("ADD " + to_ascii(reg) + " " + to_ascii(reg));
		}
	}
}

long long int firstFreeReg() {
  return 50;
}

void regToMem(long long int reg) {
	pushCmd("STORE " + to_ascii(reg));
}

void memToReg(long long int mem) {
	pushCmd("LOAD " + to_ascii(mem));
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
	long long int i;
	for(i = 0; i < asmStack.size(); i++)
        out_code << asmStack.at(i) << endl;
}


void printAsmStack(){
	long long int i;
	for(i = 0; i < asmStack.size(); i++)
        cout << asmStack.at(i) << endl;
}

int main(int argv, char* argc[]){

  flagAssign = 1;
  flagWrite = 0;
  memCounter = 5;

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
   case 5:
       return "A";
   case 6:
       return "B";
   case 7:
       return "C";
   case 8:
       return "D";
   case 9:
       return "E";
   case 10:
       return "F";
   case 11:
       return "G";
   case 12:
       return "H";
   }
   return 0;
}

//======= EXPRESSION FUNCTIONS =========//

void add(Idef a, Idef b) {
    if(a.type == "NUMBER" && b.type == "NUMBER") {
        long long int value = stoll(a.name) + stoll(b.name);
        setReg(to_string(value), assignArg.mem);
        removeIdef(a.name);
        removeIdef(b.name);
    }
    else if(a.type == "NUMBER" && b.type == "IDENTIFIER") {
        if(stoll(a.name) < 15){
            memToReg(b.mem);
            for(int i=0; i < stoll(a.name); i++) {
                pushCmd("INC " + to_ascii(b.mem));
            }
            pushCmd("COPY " + to_ascii(assignArg.mem) + " " + to_ascii(b.mem));
            removeIdef(a.name);
        }
        else {
            setReg(a.name, a.mem);
            pushCmd("ADD " + to_ascii(a.mem) + " " + to_ascii(b.mem));
            pushCmd("COPY " + to_ascii(assignArg.mem) + " " + to_ascii(a.mem));
            removeIdef(a.name);
        }
    }
    else if(a.type == "IDENTIFIER" && b.type == "NUMBER") {
        if(stoll(b.name) < 15){
            memToReg(a.mem);
            for(int i=0; i < stoll(b.name); i++) {
                pushCmd("INC " + to_ascii(a.mem));
            }
            pushCmd("COPY " + to_ascii(assignArg.mem) + " " + to_ascii(a.mem));
            removeIdef(b.name);
        }
        else {
            setReg(b.name, b.mem);
            pushCmd("ADD " + to_ascii(b.mem) + " " + to_ascii(a.mem));
            pushCmd("COPY " + to_ascii(assignArg.mem) + " " + to_ascii(b.mem));
            removeIdef(b.name);
        }
    }
    else if(a.type == "IDENTIFIER" && b.type == "IDENTIFIER") {
        if(a.name == b.name) {
            memToReg(a.mem);
            pushCmd("ADD " + to_ascii(a.mem) + " " + to_ascii(a.mem));
        }
        else {
            memToReg(a.mem);
            pushCmd("ADD " + to_ascii(a.mem) + " " +  to_ascii(b.mem));
        }
        pushCmd("COPY " + to_ascii(assignArg.mem) + " " + to_ascii(a.mem));
    }
}

void addTab(Idef a, Idef b, Idef aIndex, Idef bIndex) {
  if(a.type == "NUMBER" && b.type == "ARRAY") {
      if(bIndex.type == "NUMBER") {
          long long int addres = b.mem + stoll(bIndex.name) + 1;
          if(stoll(a.name) < 10) {
              memToReg(addres);
              for(int i=0; i < stoll(a.name); i++) {
                  pushCmd("INC " + to_ascii(b.mem));
              }
          }
          else {
              setReg(a.name, a.mem);
              pushCmd("ADD " + to_ascii(a.mem) + " " + to_ascii(addres));
          }
          removeIdef(a.name);
          removeIdef(bIndex.name);
      }
      else if(bIndex.type == "IDENTIFIER") {
          memToReg(b.mem);
          pushCmd("ADD " + to_ascii(b.mem) + " " + to_ascii(bIndex.mem));
          regToMem(1);
          if(stoll(a.name) < 10) {
              pushCmd("LOADTAB 1");
              for(int i=0; i < stoll(a.name); i++) {
                pushCmd("INC " + to_ascii(b.mem));
              }
          }
          else {
              setReg(a.name, a.mem);
              pushCmd("ADDTAB 1");
          }
          removeIdef(a.name);
      }
  }
  else if(a.type == "ARRAY" && b.type == "NUMBER") {
      if(aIndex.type == "NUMBER") {
          long long int addres = a.mem + stoll(aIndex.name) + 1;
          if(stoll(b.name) < 10) {
              memToReg(addres);
              for(int i=0; i < stoll(b.name); i++) {
                  pushCmd("INC " + to_ascii(a.mem));
              }
          }
          else {
              setReg(b.name, b.mem);
              pushCmd("ADD " + to_ascii(b.mem) + " " + to_ascii(addres));
          }
          removeIdef(b.name);
          removeIdef(aIndex.name);
      }
      else if(aIndex.type == "IDENTIFIER") {
          memToReg(a.mem);
          pushCmd("ADD " + to_ascii(a.mem) + " " + to_ascii(aIndex.mem));
          regToMem(1);
          if(stoll(b.name) < 10){
              pushCmd("LOADTAB 1");
              for(int i=0; i < stoll(b.name); i++) {
                  pushCmd("INC " + to_ascii(a.mem));
              }
          }
          else {
              setReg(b.name, b.mem);
              pushCmd("ADDTAB 1");
          }
          removeIdef(b.name);
      }
  }
  else if(a.type == "IDENTIFIER" && b.type == "ARRAY") {
      if(bIndex.type == "NUMBER") {
          long long int addres = b.mem + stoll(bIndex.name) + 1;
          memToReg(a.mem);
          pushCmd("ADD " + to_ascii(a.mem) + " " + to_ascii(addres));
          removeIdef(bIndex.name);
      }
      else if(bIndex.type == "IDENTIFIER") {
          memToReg(b.mem);
          pushCmd("ADD " + to_ascii(b.mem) + " " + to_ascii(bIndex.mem));
          regToMem(1);
          memToReg(a.mem);
          pushCmd("ADDTAB 1");
      }
  }
  else if(a.type == "ARRAY" && b.type == "IDENTIFIER") {
      if(aIndex.type == "NUMBER") {
          long long int addres = a.mem + stoll(aIndex.name) + 1;
          memToReg(b.mem);
          pushCmd("ADD " + to_ascii(b.mem) + " " + to_ascii(addres));
          removeIdef(aIndex.name);
      }
      else if(aIndex.type == "IDENTIFIER") {
          memToReg(a.mem);
          pushCmd("ADD " + to_ascii(a.mem) + " " + to_ascii(aIndex.mem));
          regToMem(1);
          memToReg(b.mem);
          pushCmd("ADDTAB 1");
      }
  }
  else if(a.type == "ARRAY" && b.type == "ARRAY") {
      if(aIndex.type == "NUMBER" && bIndex.type == "NUMBER") {
          long long int Aaddres = a.mem + stoll(aIndex.name) + 1;
          long long int Baddres = b.mem + stoll(bIndex.name) + 1;
          memToReg(Aaddres);
          pushCmd("ADD " + to_ascii(Aaddres) + " " + to_ascii(Baddres));
          removeIdef(aIndex.name);
          removeIdef(bIndex.name);
      }
      else if(aIndex.type == "NUMBER" && bIndex.type == "IDENTIFIER") {
          long long int addres = a.mem + stoll(aIndex.name) + 1;
          memToReg(b.mem);
          pushCmd("ADD " + to_ascii(b.mem) + " " + to_ascii(bIndex.mem));
          regToMem(1);
          memToReg(addres);
          pushCmd("ADDTAB 1");
          removeIdef(aIndex.name);
      }
      else if(aIndex.type == "IDENTIFIER" && bIndex.type == "NUMBER") {
          long long int addres = b.mem + stoll(bIndex.name) + 1;
          memToReg(a.mem);
          pushCmd("ADD " + to_ascii(a.mem) + " " + to_ascii(aIndex.mem));
          regToMem(1);
          memToReg(addres);
          pushCmd("ADDTAB 1");
          removeIdef(bIndex.name);
      }
      else if(aIndex.type == "IDENTIFIER" && bIndex.type == "IDENTIFIER") {
          if(a.name == b.name && aIndex.name == bIndex.name) {
              memToReg(a.mem);
              pushCmd("ADD " + to_ascii(a.mem) + " " + to_ascii(aIndex.mem));
              regToMem(1);
              pushCmd("LOADTAB 1");
              pushCmd("ADD " + to_ascii(1) + " " + to_ascii(1));
          }
          else {
              memToReg(a.mem);
              pushCmd("ADD " + to_ascii(a.mem) + " " + to_ascii(aIndex.mem));
              regToMem(1);
              memToReg(b.mem);
              pushCmd("ADD " + to_ascii(b.mem) + " " + to_ascii(bIndex.mem));
              regToMem(0);
              pushCmd("LOADTAB 1");
              pushCmd("ADDTAB 0");
          }
      }
  }
}

void sub(Idef a, Idef b) {
    if(a.type == "NUMBER" && b.type == "NUMBER") {
        long long int value = max(stoll(a.name) - stoll(b.name), (long long int) 0);
        setReg(to_ascii(value), firstFreeReg());
        removeIdef(a.name);
        removeIdef(b.name);
    }
    else if(a.type == "NUMBER" && b.type == "IDENTIFIER") {
        setReg(a.name, a.mem);
        pushCmd("SUB " + to_ascii(a.mem) + " " + to_ascii(b.mem));
        removeIdef(a.name);
    }
    else if(a.type == "IDENTIFIER" && b.type == "NUMBER") {
        setReg(b.name, b.mem);
        pushCmd("SUB " + to_ascii(a.mem) + " " + to_ascii(b.mem));
        removeIdef(b.name);
    }
    else if(a.type == "IDENTIFIER" && b.type == "IDENTIFIER") {
        memToReg(a.mem);
        pushCmd("SUB " + to_ascii(a.mem) + " " +  to_ascii(a.mem));
    }
}

void subTab(Idef a, Idef b, Idef aIndex, Idef bIndex) {
  if(a.type == "NUMBER" && b.type == "ARRAY") {
      if(bIndex.type == "NUMBER") {
          long long int addres = b.mem + stoll(bIndex.name) + 1;
          setReg(a.name, a.mem);
          pushCmd("SUB " + to_ascii(a.mem) + " " + to_ascii(addres));
          removeIdef(a.name);
          removeIdef(bIndex.name);
      }
      else if(bIndex.type == "IDENTIFIER") {
          memToReg(b.mem);
          pushCmd("SUB " + to_ascii(b.mem) + " " + to_ascii(bIndex.mem));
          regToMem(1);
          setReg(a.name, a.mem);
          pushCmd("SUBTAB 1");
          removeIdef(a.name);
      }
  }
  else if(a.type == "ARRAY" && b.type == "NUMBER") {
      if(aIndex.type == "NUMBER") {
          long long int addres = a.mem + stoll(aIndex.name) + 1;
          setReg(b.name, b.mem);
          pushCmd("SUB " + to_ascii(addres) + " " + to_ascii(b.mem));
          removeIdef(b.name);
          removeIdef(aIndex.name);
      }
      else if(aIndex.type == "IDENTIFIER") {
          memToReg(a.mem);
          pushCmd("SUB " + to_ascii(a.mem) + " " + to_ascii(aIndex.mem));
          regToMem(1);
          setReg(b.name, b.mem);
          pushCmd("SUBTAB 1");
          removeIdef(b.name);
      }
  }
  else if(a.type == "IDENTIFIER" && b.type == "ARRAY") {
      if(bIndex.type == "NUMBER") {
          long long int addres = b.mem + stoll(bIndex.name) + 1;
          memToReg(a.mem);
          pushCmd("SUB " + to_ascii(a.mem) + " " + to_ascii(addres));
          removeIdef(bIndex.name);
      }
      else if(bIndex.type == "IDENTIFIER") {
          memToReg(b.mem);
          pushCmd("SUB " + to_ascii(b.mem) + " " + to_ascii(bIndex.mem));
          regToMem(1);
          memToReg(a.mem);
          pushCmd("SUBTAB 1");
      }
  }
  else if(a.type == "ARRAY" && b.type == "IDENTIFIER") {
      if(aIndex.type == "NUMBER") {
          long long int addres = a.mem + stoll(aIndex.name) + 1;
          memToReg(b.mem);
          pushCmd("SUB " + to_ascii(addres) + " " + to_ascii(b.mem));
          removeIdef(aIndex.name);
      }
      else if(aIndex.type == "IDENTIFIER") {
          memToReg(a.mem);
          pushCmd("SUB " + to_ascii(a.mem) + " " + to_ascii(aIndex.mem));
          regToMem(1);
          memToReg(b.mem);
          pushCmd("SUBTAB 1");
      }
  }
  else if(a.type == "ARRAY" && b.type == "ARRAY") {
      if(aIndex.type == "NUMBER" && bIndex.type == "NUMBER") {
          long long int Aaddres = a.mem + stoll(aIndex.name) + 1;
          long long int Baddres = b.mem + stoll(bIndex.name) + 1;
          if(a.name == b.name && Aaddres == Baddres) {
              memToReg(Aaddres);
              pushCmd("SUB " + to_ascii(Aaddres) + " " + to_ascii(Aaddres));
          }
          else {
              memToReg(Aaddres);
              pushCmd("SUB " + to_ascii(Aaddres) + " " + to_ascii(Baddres));
          }
          removeIdef(aIndex.name);
          removeIdef(bIndex.name);
      }
      else if(aIndex.type == "NUMBER" && bIndex.type == "IDENTIFIER") {
          long long int addres = a.mem + stoll(aIndex.name) + 1;
          memToReg(b.mem);
          pushCmd("SUB " + to_ascii(b.mem) + " " + to_ascii(bIndex.mem));
          regToMem(1);
          memToReg(addres);
          pushCmd("SUBTAB 1");
          removeIdef(aIndex.name);
      }
      else if(aIndex.type == "IDENTIFIER" && bIndex.type == "NUMBER") {
          long long int addres = b.mem + stoll(bIndex.name) + 1;
          memToReg(a.mem);
          pushCmd("SUB " + to_ascii(a.mem) + " " + to_ascii(aIndex.mem));
          regToMem(1);
          memToReg(addres);
          pushCmd("SUBTAB 1");
          removeIdef(bIndex.name);
      }
      else if(aIndex.type == "IDENTIFIER" && bIndex.type == "IDENTIFIER") {
          if(a.name == b.name && aIndex.name == bIndex.name) {
              memToReg(a.mem);
              pushCmd("SUB " + to_ascii(a.mem) + " " + to_ascii(aIndex.mem));
              regToMem(1);
              pushCmd("LOADTAB 1");
              long long int temp = firstFreeReg();
              pushCmd("SUB " + to_ascii(1) + " " + to_ascii(1));
          }
          else {
              memToReg(a.mem);
              pushCmd("SUB " + to_ascii(a.mem) + " " + to_ascii(aIndex.mem));
              regToMem(1);
              memToReg(b.mem);
              pushCmd("SUB " + to_ascii(b.mem) + " " + to_ascii(bIndex.mem));
              regToMem(0);
              pushCmd("LOADTAB 1");
              pushCmd("SUBTAB 0");
          }
      }
  }
}
