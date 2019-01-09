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

  typedef struct {
      long long int placeInStack;
      long long int depth;
  } Jump;

  map<string, Idef> idefStack;
  vector<string> asmStack;
  vector<Jump> jumpStack;
  vector<Idef> forStack;
  vector<Idef> conditionStack;

  int flagAssign;
  int flagWrite;

  Idef assignArg;
  string assignArgTabIndex = "-1";
  string expressionArgs[2] = {"-1", "-1"};
  string expArgsTabIndex[2] = {"-1", "-1"};

  long long int memCounter;
  long long int depth;

  void printAsm(string outFileName);
  void printAsmStack();

  void createIdef(Idef *idef, string name, string type, long long int isLocal, long long int arraySize, long long int move);
  void insertIdef(string key, Idef i);
  void removeIdef(string key);

  void createJump(Jump *j, long long int stack, long long int depth);
  void addInt(long long int command, long long int val);

  void setReg(string number, long long int reg);
  void zeroReg(long long int reg);
  void binToAsmStack(long long int reg, string bin);
  void regToMem(long long int reg);
  void memToReg(long long int memory);
  void pushCmd(string s);

  string decToBin(long long int n);
  string to_ascii(long long int value);

  void add(Idef a, Idef b);
  void addTab(Idef a, Idef b, Idef aIndex, Idef bIndex);
  void sub(Idef a, Idef b, int isINC, int isRemoval) ;
  void subTab(Idef a, Idef b, Idef aIndex, Idef bIndex, int isINC, int isRemoval) ;
  void mul(Idef a, Idef b);
  void mulTab(Idef a, Idef b, Idef aIndex, Idef bIndex);
  void div(Idef a, Idef b);
  void divTab(Idef a, Idef b, Idef aIndex, Idef bIndex);
  void mod(Idef a, Idef b);
  void modTab(Idef a, Idef b, Idef aIndex, Idef bIndex);

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
| IF {flagAssign = 0;
        depth++;
    } condition {
        flagAssign = 1;
    } THEN commands ifbody
| DO {
      depth++;
      Jump j;
      createJump(&j, asmStack.size(), depth);
      jumpStack.push_back(j);
    } commands WHILE {
        flagAssign = 0;
    } condition ENDDO {
          long long int stack;
          long long int jumpCount = jumpStack.size()-1;

          if(jumpCount > 1 && jumpStack.at(jumpCount).depth == jumpStack.at(jumpCount-1).depth) {
              stack = jumpStack.at(jumpCount-2).placeInStack;
              pushCmd("JUMP " + to_string(stack));

              addInt(jumpStack.at(jumpCount).placeInStack, asmStack.size());
              addInt(jumpStack.at(jumpCount-1).placeInStack, asmStack.size());
              jumpStack.pop_back();
          }
          else {
              stack = jumpStack.at(jumpCount-1).placeInStack;
              pushCmd("JUMP " + to_string(stack));
              addInt(jumpStack.at(jumpCount).placeInStack, asmStack.size());
          }
          jumpStack.pop_back();
          jumpStack.pop_back();

          depth--;
    }
| WHILE {
        flagAssign = 0;
        depth++;
        Jump j;
        createJump(&j, asmStack.size(), depth);
        jumpStack.push_back(j);
    } condition {
        flagAssign = 1;
    } DO commands ENDWHILE {
        long long int stack;
        long long int jumpCount = jumpStack.size()-1;

        if(jumpCount > 1 && jumpStack.at(jumpCount).depth == jumpStack.at(jumpCount-1).depth) {
            stack = jumpStack.at(jumpCount-2).placeInStack;
            pushCmd("JUMP " + to_string(stack));

            addInt(jumpStack.at(jumpCount).placeInStack, asmStack.size());
            addInt(jumpStack.at(jumpCount-1).placeInStack, asmStack.size());
            jumpStack.pop_back();
        }
        else {
            stack = jumpStack.at(jumpCount-1).placeInStack;
            pushCmd("JUMP " + to_string(stack));
            addInt(jumpStack.at(jumpCount).placeInStack, asmStack.size());
        }
        jumpStack.pop_back();
        jumpStack.pop_back();

        depth--;
        flagAssign = 1;
    }
| FOR PIDENTIFIER {
        if(idefStack.find($2)!=idefStack.end()) {
            cout << "Błąd: linia " << yylineno << " - Redundancja zmiennej " << $<str>2 << "." << endl;
            exit(1);
        }
        else {
            Idef s;
            createIdef(&s, $2, "IDENTIFIER", 1, 0, 0);
            insertIdef($2, s);
        }
        flagAssign = 0;
        assignArg = idefStack.at($2);
        depth++;
    } FROM value forbody
| READ identifier {
        flagAssign = 1;
    }
    SEMICOLON {
      if(assignArg.type == "ARRAY") {
          Idef index = idefStack.at(assignArgTabIndex);
          if(index.type == "NUMBER") {
              pushCmd("GET H");
              long long int tabElMem = assignArg.memory + stoll(index.name) - assignArg.move + 1;
              setReg(to_string(tabElMem), 1);
              regToMem(8);
              removeIdef(index.name);
          }
          else {
              pushCmd("GET H");

              setReg(to_string(index.memory),1);
              memToReg(2);
              long long int indexFix = assignArg.memory - assignArg.move + 1;
              setReg(to_string(indexFix),3);
              if(indexFix<0){
                pushCmd("SUB B C");
              }else{
                pushCmd("ADD B C");
              }
              pushCmd("COPY A B");
              regToMem(8);
          }
      }
      else if(assignArg.isLocal == 0) {
          pushCmd("GET H");
          setReg(to_string(assignArg.memory),1);
          regToMem(8);
      }
      else {
          cout << "Błąd:linia " << yylineno << " - Próba modyfikacji iteratora pętli" << endl;
          exit(1);
      }
      idefStack.at(assignArg.name).isInitialized = 1;
      flagAssign = 1;
    }
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

ifbody:
    ELSE {
        long long int jumpCount = jumpStack.size()-1;
        Jump jump = jumpStack.at(jumpCount);
        addInt(jump.placeInStack, asmStack.size()+1);

        if((jumpCount-1) >= 0 && jumpStack.at(jumpCount).depth == jumpStack.at(jumpCount-1).depth)
        {
          addInt(jumpStack.at(jumpCount).placeInStack - 1, asmStack.size()+1);
          jumpStack.pop_back();
        }
        jumpStack.pop_back();

        Jump j;
        createJump(&j, asmStack.size(), depth);
        jumpStack.push_back(j);
        pushCmd("JUMP");

        flagAssign = 1;
    } commands ENDIF {
        addInt(jumpStack.at(jumpStack.size()-1).placeInStack, asmStack.size());

        jumpStack.pop_back();

        depth--;
        flagAssign = 1;
    }
|   ENDIF {
        long long int jumpCount = jumpStack.size()-1;
        addInt(jumpStack.at(jumpCount).placeInStack, asmStack.size());

        if((jumpCount-1) >= 0 && jumpStack.at(jumpCount).depth == jumpStack.at(jumpCount-1).depth)
        {
          addInt(jumpStack.at(jumpCount).placeInStack - 1, asmStack.size());
          jumpStack.pop_back();
        }
        jumpStack.pop_back();

        depth--;
        flagAssign = 1;
    }
;

forbody:
    DOWNTO value DO {

      Idef a = idefStack.at(expressionArgs[0]);
      Idef b = idefStack.at(expressionArgs[1]);

      if(a.type == "NUMBER") {
          setReg(a.name, 8);
      }
      else if(a.type == "IDENTIFIER") {
          setReg(to_string(a.memory), 1);
          memToReg(8);
      }
      else {
          Idef index = idefStack.at(expArgsTabIndex[0]);
          if(index.type == "NUMBER") {
              long long int tabElMem = a.memory + stoll(index.name) - a.move + 1;
              setReg(to_string(tabElMem),1);
              memToReg(8);
          }
          else {
              setReg(to_string(index.memory),1);
              memToReg(2);
              long long int indexFix = a.memory - a.move + 1;
              setReg(to_string(indexFix),3);
              if(indexFix<0){
                pushCmd("SUB B C");
              }else{
                pushCmd("ADD B C");
              }
              pushCmd("COPY A B");
              memToReg(8);
          }
      }
      setReg(to_string(assignArg.memory),1);
      regToMem(8);
      idefStack.at(assignArg.name).isInitialized = 1;

      if(a.type != "ARRAY" && b.type != "ARRAY") {
          sub(a, b, 1, 1);
        }
      else {
          Idef aI, bI;
          if(idefStack.count(expArgsTabIndex[0]) > 0)
              aI = idefStack.at(expArgsTabIndex[0]);
          if(idefStack.count(expArgsTabIndex[1]) > 0)
              bI = idefStack.at(expArgsTabIndex[1]);
          subTab(a, b, aI, bI, 1, 1);
          expArgsTabIndex[0] = "-1";
          expArgsTabIndex[1] = "-1";
      }
      expressionArgs[0] = "-1";
      expressionArgs[1] = "-1";

      Idef s;
      string name = "C" + to_string(depth);
      createIdef(&s, name, "IDENTIFIER", 1, 0, 0);
      insertIdef(name, s);
      setReg(to_string(idefStack.at(name).memory),1);
      regToMem(8);

      forStack.push_back(idefStack.at(assignArg.name));

      Jump j;
      createJump(&j, asmStack.size(), depth);
      jumpStack.push_back(j);

      setReg(to_string(idefStack.at(name).memory),1);
      memToReg(7);

      Jump jj;
      createJump(&jj, asmStack.size(), depth);
      jumpStack.push_back(jj);

      pushCmd("JZERO G");
      pushCmd("DEC G");
      regToMem(7);

      flagAssign = 1;
    } commands ENDFOR {
      Idef iterator = forStack.at(forStack.size()-1);
      setReg(to_string(iterator.memory),1);
      memToReg(2);
      pushCmd("DEC B");
      regToMem(2);

      long long int jumpCount = jumpStack.size()-2;
      long long int stack = jumpStack.at(jumpCount).placeInStack;

      long long int jumpCount2 = jumpStack.size()-1;
      long long int stack2 = jumpStack.at(jumpCount2).placeInStack;

      pushCmd("JUMP " + to_string(stack));
      addInt(stack2, asmStack.size());
      jumpStack.pop_back();
      jumpStack.pop_back();

      string name = "C" + to_string(depth);
      removeIdef(name);
      removeIdef(iterator.name);
      forStack.pop_back();

      depth--;
      flagAssign = 1;
    }
    |   TO value DO {

            Idef a = idefStack.at(expressionArgs[0]);
            Idef b = idefStack.at(expressionArgs[1]);

            if(a.type == "NUMBER") {
                setReg(a.name, 8);
            }
            else if(a.type == "IDENTIFIER") {
                setReg(to_string(a.memory), 1);
                memToReg(8);
            }
            else {
                Idef index = idefStack.at(expArgsTabIndex[0]);
                if(index.type == "NUMBER") {
                    long long int tabElMem = a.memory + stoll(index.name) - a.move + 1;
                    setReg(to_string(tabElMem),1);
                    memToReg(8);
                }
                else {
                    setReg(to_string(index.memory),1);
                    memToReg(2);
                    long long int indexFix = a.memory - a.move + 1;
                    setReg(to_string(indexFix),3);
                    if(indexFix<0){
                      pushCmd("SUB B C");
                    }else{
                      pushCmd("ADD B C");
                    }
                    pushCmd("COPY A B");
                    memToReg(8);
                }
            }
            setReg(to_string(assignArg.memory),1);
            regToMem(8);
            idefStack.at(assignArg.name).isInitialized = 1;

            if(a.type != "ARRAY" && b.type != "ARRAY") {
                sub(b, a, 1, 1);
              }
            else {
                Idef aI, bI;
                if(idefStack.count(expArgsTabIndex[0]) > 0)
                    aI = idefStack.at(expArgsTabIndex[0]);
                if(idefStack.count(expArgsTabIndex[1]) > 0)
                    bI = idefStack.at(expArgsTabIndex[1]);
                subTab(b, a, bI, aI, 1, 1);
                expArgsTabIndex[0] = "-1";
                expArgsTabIndex[1] = "-1";
            }
            expressionArgs[0] = "-1";
            expressionArgs[1] = "-1";

            Idef s;
            string name = "C" + to_string(depth);
            createIdef(&s, name, "IDENTIFIER", 1, 0, 0);
            insertIdef(name, s);
            setReg(to_string(idefStack.at(name).memory),1);
            regToMem(8);

            forStack.push_back(idefStack.at(assignArg.name));

            Jump j;
            createJump(&j, asmStack.size(), depth);
            jumpStack.push_back(j);

            setReg(to_string(idefStack.at(name).memory),1);
            memToReg(7);

            Jump jj;
            createJump(&jj, asmStack.size(), depth);
            jumpStack.push_back(jj);

            pushCmd("JZERO G");
            pushCmd("DEC G");
            regToMem(7);

            flagAssign = 1;

        } commands ENDFOR {
            Idef iterator = forStack.at(forStack.size()-1);
            setReg(to_string(iterator.memory),1);
            memToReg(2);
            pushCmd("INC B");
            regToMem(2);

            long long int jumpCount = jumpStack.size()-2;
            long long int stack = jumpStack.at(jumpCount).placeInStack;

            long long int jumpCount2 = jumpStack.size()-1;
            long long int stack2 = jumpStack.at(jumpCount2).placeInStack;

            pushCmd("JUMP " + to_string(stack));
            addInt(stack2, asmStack.size());
            jumpStack.pop_back();
            jumpStack.pop_back();

            string name = "C" + to_string(depth);
            removeIdef(name);
            removeIdef(iterator.name);
            forStack.pop_back();

            depth--;
            flagAssign = 1;
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
| value ADD value {
        Idef a = idefStack.at(expressionArgs[0]);
        Idef b = idefStack.at(expressionArgs[1]);
        if(a.type != "ARRAY" && b.type != "ARRAY")
            add(a, b);
        else {
            Idef aI, bI;
            if(idefStack.count(expArgsTabIndex[0]) > 0)
                aI = idefStack.at(expArgsTabIndex[0]);
            if(idefStack.count(expArgsTabIndex[1]) > 0)
                bI = idefStack.at(expArgsTabIndex[1]);
            addTab(a, b, aI, bI);
            expArgsTabIndex[0] = "-1";
            expArgsTabIndex[1] = "-1";
        }
        expressionArgs[0] = "-1";
        expressionArgs[1] = "-1";
    }
| value SUBSTRACT value {
        Idef a = idefStack.at(expressionArgs[0]);
        Idef b = idefStack.at(expressionArgs[1]);
        if(a.type != "ARRAY" && b.type != "ARRAY")
            sub(a, b, 0, 1);
        else {
            Idef aI, bI;
            if(idefStack.count(expArgsTabIndex[0]) > 0)
                aI = idefStack.at(expArgsTabIndex[0]);
            if(idefStack.count(expArgsTabIndex[1]) > 0)
                bI = idefStack.at(expArgsTabIndex[1]);
            subTab(a, b, aI, bI, 0, 1);
            expArgsTabIndex[0] = "-1";
            expArgsTabIndex[1] = "-1";
        }
        expressionArgs[0] = "-1";
        expressionArgs[1] = "-1";
    }
| value MULTIPLY value {
  Idef a = idefStack.at(expressionArgs[0]);
  Idef b = idefStack.at(expressionArgs[1]);
  Idef aI, bI;
  if(a.type != "ARRAY" && b.type != "ARRAY")
      mul(a, b);
  else {
      Idef aI, bI;
      if(idefStack.count(expArgsTabIndex[0]) > 0)
          aI = idefStack.at(expArgsTabIndex[0]);
      if(idefStack.count(expArgsTabIndex[1]) > 0)
          bI = idefStack.at(expArgsTabIndex[1]);
      mulTab(a, b, aI, bI);
      expArgsTabIndex[0] = "-1";
      expArgsTabIndex[1] = "-1";
  }
  expressionArgs[0] = "-1";
  expressionArgs[1] = "-1";
}
| value DIVIDE value {
  Idef a = idefStack.at(expressionArgs[0]);
  Idef b = idefStack.at(expressionArgs[1]);
  Idef aI, bI;
  if(a.type != "ARRAY" && b.type != "ARRAY")
      div(a, b);
  else {
      Idef aI, bI;
      if(idefStack.count(expArgsTabIndex[0]) > 0)
          aI = idefStack.at(expArgsTabIndex[0]);
      if(idefStack.count(expArgsTabIndex[1]) > 0)
          bI = idefStack.at(expArgsTabIndex[1]);
      divTab(a, b, aI, bI);
      expArgsTabIndex[0] = "-1";
      expArgsTabIndex[1] = "-1";
  }
  expressionArgs[0] = "-1";
  expressionArgs[1] = "-1";
}
| value MOD value {
  Idef a = idefStack.at(expressionArgs[0]);
  Idef b = idefStack.at(expressionArgs[1]);
  Idef aI, bI;
  if(a.type != "ARRAY" && b.type != "ARRAY")
      mod(a, b);
  else {
      Idef aI, bI;
      if(idefStack.count(expArgsTabIndex[0]) > 0)
          aI = idefStack.at(expArgsTabIndex[0]);
      if(idefStack.count(expArgsTabIndex[1]) > 0)
          bI = idefStack.at(expArgsTabIndex[1]);
      modTab(a, b, aI, bI);
      expArgsTabIndex[0] = "-1";
      expArgsTabIndex[1] = "-1";
  }
  expressionArgs[0] = "-1";
  expressionArgs[1] = "-1";
}
;

condition:
value EQUAL value {
  Idef a = idefStack.at(expressionArgs[0]);
  Idef b = idefStack.at(expressionArgs[1]);
  if(a.type == "NUMBER" && b.type == "NUMBER") {
      if(stoll(a.name) == stoll(b.name))
          setReg("1", 8);
      else
          setReg("0", 8);

      removeIdef(a.name);
      removeIdef(b.name);

      Jump j;
      createJump(&j, asmStack.size(), depth+20);
      jumpStack.push_back(j);
      pushCmd("JZERO H");
  }
  else {
      Idef aI, bI;
      if(idefStack.count(expArgsTabIndex[0]) > 0)
          aI = idefStack.at(expArgsTabIndex[0]);
      if(idefStack.count(expArgsTabIndex[1]) > 0)
          bI = idefStack.at(expArgsTabIndex[1]);

      if(a.type != "ARRAY" && b.type != "ARRAY")
          sub(a, b, 1, 0);
      else
          subTab(a, b, aI, bI, 1, 0);

      pushCmd("COPY F H");

      if(a.type != "ARRAY" && b.type != "ARRAY")
          sub(b, a, 1, 0);
      else
          subTab(b, a, bI, aI, 1, 0);

      pushCmd("COPY G H");


      Jump j;
      createJump(&j, asmStack.size(), depth+20);
      jumpStack.push_back(j);
      pushCmd("JZERO F");

      Jump jj;
      createJump(&jj, asmStack.size(), depth+20);
      jumpStack.push_back(jj);
      pushCmd("JZERO G");
  }
  expArgsTabIndex[0] = "-1";
  expArgsTabIndex[1] = "-1";
  expressionArgs[0] = "-1";
  expressionArgs[1] = "-1";
}
| value NOTEQUAL value {
  Idef a = idefStack.at(expressionArgs[0]);
  Idef b = idefStack.at(expressionArgs[1]);
  if(a.type == "NUMBER" && b.type == "NUMBER") {
      if(stoll(a.name) != stoll(b.name))
          setReg("1", 8);
      else
          setReg("0", 8);

      removeIdef(a.name);
      removeIdef(b.name);

      Jump j;
      createJump(&j, asmStack.size(), depth+20);
      jumpStack.push_back(j);
      pushCmd("JZERO H");
  }
  else {
      Idef aI, bI;
      if(idefStack.count(expArgsTabIndex[0]) > 0)
          aI = idefStack.at(expArgsTabIndex[0]);
      if(idefStack.count(expArgsTabIndex[1]) > 0)
          bI = idefStack.at(expArgsTabIndex[1]);

      if(a.type != "ARRAY" && b.type != "ARRAY")
          sub(b, a, 0, 0);
      else
          subTab(b, a, bI, aI, 0, 0);

      pushCmd("JZERO H " + to_string(asmStack.size()+2));

      Jump j;
      createJump(&j, asmStack.size(), depth+20);
      jumpStack.push_back(j);
      pushCmd("JUMP");

      if(a.type != "ARRAY" && b.type != "ARRAY")
          sub(a, b, 0, 1);
      else
          subTab(a, b, aI, bI, 0, 1);

      addInt(jumpStack.at(jumpStack.size()-1).placeInStack, asmStack.size()+1);
      jumpStack.pop_back();

      Jump jj;
      createJump(&jj, asmStack.size(), depth+20);
      jumpStack.push_back(jj);
      pushCmd("JZERO H");
  }
  expArgsTabIndex[0] = "-1";
  expArgsTabIndex[1] = "-1";
  expressionArgs[0] = "-1";
  expressionArgs[1] = "-1";
}
| value LEFTINEQUAL value {
  Idef a = idefStack.at(expressionArgs[0]);
  Idef b = idefStack.at(expressionArgs[1]);
  if(a.type == "NUMBER" && b.type == "NUMBER") {
      if(stoll(a.name) < stoll(b.name))
          setReg("1", 8);
      else
          setReg("0", 8);

      removeIdef(a.name);
      removeIdef(b.name);
    }
    else {
        if(a.type != "ARRAY" && b.type != "ARRAY")
            sub(b, a, 0, 1);
        else {
            Idef aI, bI;
            if(idefStack.count(expArgsTabIndex[0]) > 0)
                aI = idefStack.at(expArgsTabIndex[0]);
            if(idefStack.count(expArgsTabIndex[1]) > 0)
                bI = idefStack.at(expArgsTabIndex[1]);
            subTab(b, a, bI, aI, 0, 1);
            expArgsTabIndex[0] = "-1";
            expArgsTabIndex[1] = "-1";
        }
    }

    Jump j;
    createJump(&j, asmStack.size(), depth+20);
    jumpStack.push_back(j);
    pushCmd("JZERO H");

    expressionArgs[0] = "-1";
    expressionArgs[1] = "-1";
  }
| value RIGHTINEQUAL value {
  Idef a = idefStack.at(expressionArgs[0]);
  Idef b = idefStack.at(expressionArgs[1]);
  if(a.type == "NUMBER" && b.type == "NUMBER") {
      if(stoll(a.name) > stoll(b.name))
          setReg("1", 8);
      else
          setReg("0", 8);

      removeIdef(a.name);
      removeIdef(b.name);
    }
    else {
        if(a.type != "ARRAY" && b.type != "ARRAY")
            sub(a, b, 0, 1);
        else {
            Idef aI, bI;
            if(idefStack.count(expArgsTabIndex[0]) > 0)
                aI = idefStack.at(expArgsTabIndex[0]);
            if(idefStack.count(expArgsTabIndex[1]) > 0)
                bI = idefStack.at(expArgsTabIndex[1]);
            subTab(a, b, aI, bI, 0, 1);
            expArgsTabIndex[0] = "-1";
            expArgsTabIndex[1] = "-1";
        }
    }

    Jump j;
    createJump(&j, asmStack.size(), depth+20);
    jumpStack.push_back(j);
    pushCmd("JZERO H");

    expressionArgs[0] = "-1";
    expressionArgs[1] = "-1";
  }
| value LEFTINEQUALEQUAL value {
  Idef a = idefStack.at(expressionArgs[0]);
  Idef b = idefStack.at(expressionArgs[1]);
  if(a.type == "NUMBER" && b.type == "NUMBER") {
      if(stoll(a.name) <= stoll(b.name))
          setReg("1", 8);
      else
          setReg("0", 8);

      removeIdef(a.name);
      removeIdef(b.name);
    }
    else {
        if(a.type != "ARRAY" && b.type != "ARRAY")
            sub(b, a, 1, 1);
        else {
            Idef aI, bI;
            if(idefStack.count(expArgsTabIndex[0]) > 0)
                aI = idefStack.at(expArgsTabIndex[0]);
            if(idefStack.count(expArgsTabIndex[1]) > 0)
                bI = idefStack.at(expArgsTabIndex[1]);
            subTab(b, a, bI, aI, 1, 1);
            expArgsTabIndex[0] = "-1";
            expArgsTabIndex[1] = "-1";
        }
    }

    Jump j;
    createJump(&j, asmStack.size(), depth+20);
    jumpStack.push_back(j);
    pushCmd("JZERO H");

    expressionArgs[0] = "-1";
    expressionArgs[1] = "-1";
  }
| value RIGHTINEQUALEQUAL value {
  Idef a = idefStack.at(expressionArgs[0]);
  Idef b = idefStack.at(expressionArgs[1]);
  if(a.type == "NUMBER" && b.type == "NUMBER") {
      if(stoll(a.name) >= stoll(b.name))
          setReg("1", 8);
      else
          setReg("0", 8);

      removeIdef(a.name);
      removeIdef(b.name);
    }
    else {
        if(a.type != "ARRAY" && b.type != "ARRAY")
            sub(a, b, 1, 1);
        else {
            Idef aI, bI;
            if(idefStack.count(expArgsTabIndex[0]) > 0)
                aI = idefStack.at(expArgsTabIndex[0]);
            if(idefStack.count(expArgsTabIndex[1]) > 0)
                bI = idefStack.at(expArgsTabIndex[1]);
            subTab(a, b, aI, bI, 1, 1);
            expArgsTabIndex[0] = "-1";
            expArgsTabIndex[1] = "-1";
        }
    }

    Jump j;
    createJump(&j, asmStack.size(), depth+20);
    jumpStack.push_back(j);
    pushCmd("JZERO H");

    expressionArgs[0] = "-1";
    expressionArgs[1] = "-1";
  }
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

void createJump(Jump *j, long long int stack, long long int depth) {
    j->placeInStack = stack;
    j->depth = depth;
}

void addInt(long long int command, long long int val) {
    asmStack.at(command) = asmStack.at(command) + " " + to_string(val);
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
  depth = 0;

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

void add(Idef a, Idef b) {
    if(a.type == "NUMBER" && b.type == "NUMBER") {
        long long int val = stoll(a.name) + stoll(b.name);
        setReg(to_string(val),8);
        removeIdef(a.name);
        removeIdef(b.name);
    }
    else if(a.type == "NUMBER" && b.type == "IDENTIFIER") {
        setReg(to_string(b.memory),1);
        memToReg(2);
        setReg(a.name, 8);
        pushCmd("ADD H B");
        removeIdef(a.name);
    }
    else if(a.type == "IDENTIFIER" && b.type == "NUMBER") {
        setReg(to_string(a.memory),1);
        memToReg(8);
        setReg(b.name, 2);
        pushCmd("ADD H B");
        removeIdef(b.name);
    }
    else if(a.type == "IDENTIFIER" && b.type == "IDENTIFIER") {

      if(a.name == b.name) {
        setReg(to_string(a.memory),1);
        memToReg(8);
        pushCmd("ADD H H");
        return;
      }

        setReg(to_string(a.memory),1);
        memToReg(8);
        setReg(to_string(b.memory),1);
        memToReg(2);
        pushCmd("ADD H B");
    }
}

void addTab(Idef a, Idef b, Idef aIndex, Idef bIndex) {
  if(a.type == "NUMBER" && b.type == "ARRAY") {
      if(bIndex.type == "NUMBER") {
          long long int addr = b.memory + stoll(bIndex.name) - b.move + 1;
          setReg(to_string(addr),1);
          memToReg(2);
          setReg(a.name, 8);
          pushCmd("ADD H B");
          removeIdef(a.name);
      }
      else if(bIndex.type == "IDENTIFIER") {
          setReg(to_string(bIndex.memory),1);
          memToReg(2);
          long long int indexFix = b.memory - b.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB B C");
          }else{
            pushCmd("ADD B C");
          }
          pushCmd("COPY A B");
          memToReg(2);
          setReg(a.name, 8);
          pushCmd("ADD H B");
          removeIdef(a.name);
      }
  }
  else if(a.type == "ARRAY" && b.type == "NUMBER") {
        if(aIndex.type == "NUMBER") {
            long long int addr = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addr),1);
            memToReg(8);
            setReg(b.name, 2);
            pushCmd("ADD H B");
            removeIdef(b.name);
        }
        else if(aIndex.type == "IDENTIFIER") {
            setReg(to_string(aIndex.memory),1);
            memToReg(2);
            long long int indexFix = a.memory - a.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(8);
            setReg(b.name, 2);
            pushCmd("ADD H B");
            removeIdef(b.name);
        }
    }
    else if(a.type == "IDENTIFIER" && b.type == "ARRAY") {
        if(bIndex.type == "NUMBER") {
            long long int addr = b.memory + stoll(bIndex.name) - b.move + 1;
            setReg(to_string(addr),1);
            memToReg(2);
            setReg(to_string(a.memory),1);
            memToReg(8);
            pushCmd("ADD H B");
        }
        else if(bIndex.type == "IDENTIFIER") {
            setReg(to_string(bIndex.memory),1);
            memToReg(2);
            long long int indexFix = b.memory - b.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(2);
            setReg(to_string(a.memory),1);
            memToReg(8);
            pushCmd("ADD H B");
        }
    }
    else if(a.type == "ARRAY" && b.type == "IDENTIFIER") {
        if(aIndex.type == "NUMBER") {
            long long int addr = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addr),1);
            memToReg(8);
            setReg(to_string(b.memory),1);
            memToReg(2);
            pushCmd("ADD H B");
        }
        else if(aIndex.type == "IDENTIFIER") {
            setReg(to_string(aIndex.memory),1);
            memToReg(2);

            long long int indexFix = a.memory - a.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(8);
            setReg(to_string(b.memory),1);
            memToReg(2);
            pushCmd("ADD H B");
        }
    }
    else if(a.type == "ARRAY" && b.type == "ARRAY") {
        if(aIndex.type == "NUMBER" && bIndex.type == "NUMBER") {
            long long int addrA = a.memory + stoll(aIndex.name) - a.move + 1;
            long long int addrB = b.memory + stoll(bIndex.name) - b.move + 1;
            setReg(to_string(addrA),1);
            memToReg(8);
            setReg(to_string(addrB),1);
            memToReg(2);
            pushCmd("ADD H B");
            removeIdef(aIndex.name);
            removeIdef(bIndex.name);
        }
        else if(aIndex.type == "NUMBER" && bIndex.type == "IDENTIFIER") {
            long long int addrA = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addrA),1);
            memToReg(8);
            setReg(to_string(bIndex.memory),1);
            memToReg(2);
            long long int indexFix = b.memory - b.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(2);
            pushCmd("ADD H B");
            removeIdef(aIndex.name);
        }
        else if(aIndex.type == "IDENTIFIER" && bIndex.type == "NUMBER") {
          long long int addrB = b.memory + stoll(bIndex.name) - b.move + 1;
          setReg(to_string(addrB),1);
          memToReg(2);
          setReg(to_string(aIndex.memory),1);
          memToReg(8);
          long long int indexFix = a.memory - a.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB H C");
          }else{
            pushCmd("ADD H C");
          }
          pushCmd("COPY A H");
          memToReg(8);
          pushCmd("ADD H B");
          removeIdef(bIndex.name);
        }
        else if(aIndex.type == "IDENTIFIER" && bIndex.type == "IDENTIFIER") {
          setReg(to_string(bIndex.memory),1);
          memToReg(2);
          long long int indexFix = b.memory - b.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB B C");
          }else{
            pushCmd("ADD B C");
          }
          pushCmd("COPY A B");
          memToReg(2);

          setReg(to_string(aIndex.memory),1);
          memToReg(8);
          indexFix = a.memory - a.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB H C");
          }else{
            pushCmd("ADD H C");
          }
          pushCmd("COPY A H");
          memToReg(8);

          pushCmd("ADD H B");
        }
    }
}

void sub(Idef a, Idef b, int isINC, int isRemoval)  {
    if(a.type == "NUMBER" && b.type == "NUMBER") {
        long long int val = max(stoll(a.name) + isINC - stoll(b.name),(long long int) 0);
        setReg(to_string(val),8);
        if(isRemoval) {
          removeIdef(a.name);
          removeIdef(b.name);
        }
    }
    else if(a.type == "NUMBER" && b.type == "IDENTIFIER") {
        setReg(to_string(b.memory),1);
        memToReg(2);
        setReg(to_string(stoll(a.name) + isINC), 8);
        pushCmd("SUB H B");
        if(isRemoval)
          removeIdef(a.name);
    }
    else if(a.type == "IDENTIFIER" && b.type == "NUMBER") {

      if(stoll(b.name) < 28){
        setReg(to_string(a.memory),1);
        memToReg(8);
        if(isINC)
            pushCmd("INC H");
        for(int i=0; i<stoll(b.name);i++ )
          pushCmd("DEC H");
        if(isRemoval)
          removeIdef(b.name);
        return;
      }

        setReg(to_string(a.memory),1);
        memToReg(8);
        if(isINC)
            pushCmd("INC H");
        setReg(b.name, 2);
        pushCmd("SUB H B");
        if(isRemoval)
          removeIdef(b.name);
    }
    else if(a.type == "IDENTIFIER" && b.type == "IDENTIFIER") {

      if(a.name == b.name) {
        setReg("0",8);
        return;
      }

        setReg(to_string(a.memory),1);
        memToReg(8);
        if(isINC)
            pushCmd("INC H");
        setReg(to_string(b.memory),1);
        memToReg(2);
        pushCmd("SUB H B");
    }
}

void subTab(Idef a, Idef b, Idef aIndex, Idef bIndex, int isINC, int isRemoval) {
  if(a.type == "NUMBER" && b.type == "ARRAY") {
      if(bIndex.type == "NUMBER") {
          long long int addr = b.memory + stoll(bIndex.name) - b.move + 1;
          setReg(to_string(addr),1);
          memToReg(2);
          setReg(to_string(stoll(a.name) + isINC), 8);
          pushCmd("SUB H B");
          if(isRemoval) {
              removeIdef(a.name);
              removeIdef(bIndex.name);
          }
      }
      else if(bIndex.type == "IDENTIFIER") {
          setReg(to_string(bIndex.memory),1);
          memToReg(2);
          long long int indexFix = b.memory - b.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB B C");
          }else{
            pushCmd("ADD B C");
          }
          pushCmd("COPY A B");
          memToReg(2);
          setReg(to_string(stoll(a.name) + isINC), 8);
          pushCmd("SUB H B");
          if(isRemoval)
            removeIdef(a.name);
      }
  }
  else if(a.type == "ARRAY" && b.type == "NUMBER") {
        if(aIndex.type == "NUMBER") {

          if(stoll(b.name) < 28){
            long long int addr = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addr),1);
            memToReg(8);
            if(isINC)
                pushCmd("INC H");
            for(int i=0; i<stoll(b.name);i++ )
              pushCmd("DEC H");
            if(isRemoval)
              removeIdef(b.name);
            return;
          }

            long long int addr = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addr),1);
            memToReg(8);
            if(isINC)
                pushCmd("INC H");
            setReg(b.name, 2);
            pushCmd("SUB H B");
            if(isRemoval) {
                removeIdef(b.name);
                removeIdef(aIndex.name);
            }
        }
        else if(aIndex.type == "IDENTIFIER") {

          if(stoll(b.name) < 28){
            setReg(to_string(aIndex.memory),1);
            memToReg(2);
            long long int indexFix = a.memory - a.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(8);
            if(isINC)
                pushCmd("INC H");
            for(int i=0; i<stoll(b.name);i++ )
              pushCmd("DEC H");
            if(isRemoval)
              removeIdef(b.name);
            return;
          }

            setReg(to_string(aIndex.memory),1);
            memToReg(2);
            long long int indexFix = a.memory - a.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(8);
            if(isINC)
                pushCmd("INC H");
            setReg(b.name, 2);
            pushCmd("SUB H B");
            if(isRemoval)
              removeIdef(b.name);
        }
    }
    else if(a.type == "IDENTIFIER" && b.type == "ARRAY") {
        if(bIndex.type == "NUMBER") {
            long long int addr = b.memory + stoll(bIndex.name) - b.move + 1;
            setReg(to_string(addr),1);
            memToReg(2);
            setReg(to_string(a.memory),1);
            memToReg(8);
            if(isINC)
                pushCmd("INC H");
            pushCmd("SUB H B");
            if(isRemoval)
                removeIdef(bIndex.name);
        }
        else if(bIndex.type == "IDENTIFIER") {
            setReg(to_string(bIndex.memory),1);
            memToReg(2);
            long long int indexFix = b.memory - b.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(2);
            setReg(to_string(a.memory),1);
            memToReg(8);
            if(isINC)
                pushCmd("INC H");
            pushCmd("SUB H B");
        }
    }
    else if(a.type == "ARRAY" && b.type == "IDENTIFIER") {
        if(aIndex.type == "NUMBER") {
            long long int addr = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addr),1);
            memToReg(8);

            if(isINC)
                pushCmd("INC H");

            setReg(to_string(b.memory),1);
            memToReg(2);
            pushCmd("SUB H B");
            if(isRemoval)
                removeIdef(aIndex.name);
        }
        else if(aIndex.type == "IDENTIFIER") {
            setReg(to_string(aIndex.memory),1);
            memToReg(2);

            long long int indexFix = a.memory - a.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(8);

            if(isINC)
                pushCmd("INC H");

            setReg(to_string(b.memory),1);
            memToReg(2);
            pushCmd("SUB H B");
        }
    }
    else if(a.type == "ARRAY" && b.type == "ARRAY") {
        if(aIndex.type == "NUMBER" && bIndex.type == "NUMBER") {
            long long int addrA = a.memory + stoll(aIndex.name) - a.move + 1;
            long long int addrB = b.memory + stoll(bIndex.name) - b.move + 1;
            setReg(to_string(addrA),1);
            memToReg(8);
            if(isINC)
                pushCmd("INC H");
            setReg(to_string(addrB),1);
            memToReg(2);
            pushCmd("SUB H B");
            if(isRemoval) {
                removeIdef(aIndex.name);
                removeIdef(bIndex.name);
            }
        }
        else if(aIndex.type == "NUMBER" && bIndex.type == "IDENTIFIER") {
            long long int addrA = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addrA),1);
            memToReg(8);

            if(isINC)
                pushCmd("INC H");

            setReg(to_string(bIndex.memory),1);
            memToReg(2);
            long long int indexFix = b.memory - b.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(2);
            pushCmd("SUB H B");
            if(isRemoval)
                removeIdef(aIndex.name);
        }
        else if(aIndex.type == "IDENTIFIER" && bIndex.type == "NUMBER") {
          long long int addrB = b.memory + stoll(bIndex.name) - b.move + 1;
          setReg(to_string(addrB),1);
          memToReg(2);
          setReg(to_string(aIndex.memory),1);
          memToReg(8);
          long long int indexFix = a.memory - a.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB H C");
          }else{
            pushCmd("ADD H C");
          }
          pushCmd("COPY A H");
          memToReg(8);

          if(isINC)
              pushCmd("INC H");

          pushCmd("SUB H B");
          if(isRemoval)
              removeIdef(bIndex.name);
        }
        else if(aIndex.type == "IDENTIFIER" && bIndex.type == "IDENTIFIER") {
          setReg(to_string(bIndex.memory),1);
          memToReg(2);
          long long int indexFix = b.memory - b.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB B C");
          }else{
            pushCmd("ADD B C");
          }
          pushCmd("COPY A B");
          memToReg(2);

          setReg(to_string(aIndex.memory),1);
          memToReg(8);
          indexFix = a.memory - a.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB H C");
          }else{
            pushCmd("ADD H C");
          }
          pushCmd("COPY A H");
          memToReg(8);
          if(isINC)
              pushCmd("INC H");
          pushCmd("SUB H B");
        }
    }
}

void mul(Idef a, Idef b) {
    if(a.type == "NUMBER" && b.type == "NUMBER") {
        long long int val = stoll(a.name) * stoll(b.name);
        setReg(to_string(val),8);
        removeIdef(a.name);
        removeIdef(b.name);
    }
    else if(a.type == "NUMBER" && b.type == "IDENTIFIER") {
        setReg(to_string(b.memory),1);
        memToReg(2);

        if(stoll(a.name) == 0) {
          setReg("0", 8);
          return;
        }

        long long int va = stoll(a.name);

        setReg("0",8);
        while (va>0) {
          if(va%2==1)
            pushCmd("ADD H B");
          pushCmd("ADD B B");
          va/=2;
        }
        removeIdef(a.name);
    }
    else if(a.type == "IDENTIFIER" && b.type == "NUMBER") {
        setReg(to_string(a.memory),1);
        memToReg(2);

        if(stoll(b.name) == 0) {
          setReg("0", 8);
          return;
        }

        long long int va = stoll(b.name);

        setReg("0",8);
        while (va>0) {
          if(va%2==1)
            pushCmd("ADD H B");
          pushCmd("ADD B B");
          va/=2;
        }
        removeIdef(b.name);
    }
    else if(a.type == "IDENTIFIER" && b.type == "IDENTIFIER") {
        setReg(to_string(a.memory),1);
        memToReg(2);
        setReg(to_string(b.memory),1);
        memToReg(3);

        setReg("0",8);
        long long int number = asmStack.size();
        pushCmd("JZERO C " + to_string(number + 7));
        pushCmd("JODD C " + to_string(number + 3));
        pushCmd("JUMP" + to_string(number + 4));
        pushCmd("ADD H B");
        pushCmd("ADD B B");
        pushCmd("HALF C");
        pushCmd("JUMP" + to_string(number));
    }
}

void mulTab(Idef a, Idef b, Idef aIndex, Idef bIndex) {
  if(a.type == "NUMBER" && b.type == "ARRAY") {
      if(bIndex.type == "NUMBER") {
          long long int addr = b.memory + stoll(bIndex.name) - b.move + 1;
          setReg(to_string(addr),1);
          memToReg(2);

          if(stoll(a.name) == 0) {
            setReg("0", 8);
            return;
          }

          long long int va = stoll(a.name);

          setReg("0",8);
          while (va>0) {
            if(va%2==1)
              pushCmd("ADD H B");
            pushCmd("ADD B B");
            va/=2;
          }

          removeIdef(a.name);
      }
      else if(bIndex.type == "IDENTIFIER") {
          setReg(to_string(bIndex.memory),1);
          memToReg(2);
          long long int indexFix = b.memory - b.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB B C");
          }else{
            pushCmd("ADD B C");
          }
          pushCmd("COPY A B");
          memToReg(2);
          setReg(a.name, 8);

          if(stoll(a.name) == 0) {
            setReg("0", 8);
            return;
          }

          long long int va = stoll(a.name);

          setReg("0",8);
          while (va>0) {
            if(va%2==1)
              pushCmd("ADD H B");
            pushCmd("ADD B B");
            va/=2;
          }
          removeIdef(a.name);
      }
  }
  else if(a.type == "ARRAY" && b.type == "NUMBER") {
        if(aIndex.type == "NUMBER") {
            long long int addr = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addr),1);
            memToReg(2);

            if(stoll(b.name) == 0) {
              setReg("0", 8);
              return;
            }

            long long int va = stoll(b.name);

            setReg("0",8);
            while (va>0) {
              if(va%2==1)
                pushCmd("ADD H B");
              pushCmd("ADD B B");
              va/=2;
            }

            removeIdef(b.name);
        }
        else if(aIndex.type == "IDENTIFIER") {
            setReg(to_string(aIndex.memory),1);
            memToReg(2);
            long long int indexFix = a.memory - a.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(2);
            if(stoll(b.name) == 0) {
              setReg("0", 8);
              return;
            }

            long long int va = stoll(b.name);

            setReg("0",8);
            while (va>0) {
              if(va%2==1)
                pushCmd("ADD H B");
              pushCmd("ADD B B");
              va/=2;
            }

            removeIdef(b.name);
        }
    }
    else if(a.type == "IDENTIFIER" && b.type == "ARRAY") {
        if(bIndex.type == "NUMBER") {
            long long int addr = b.memory + stoll(bIndex.name) - b.move + 1;
            setReg(to_string(addr),1);
            memToReg(3);
            setReg(to_string(a.memory),1);
            memToReg(2);

            setReg("0",8);
            long long int number = asmStack.size();
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("JODD C " + to_string(number + 3));
            pushCmd("JUMP" + to_string(number + 4));
            pushCmd("ADD H B");
            pushCmd("ADD B B");
            pushCmd("HALF C");
            pushCmd("JUMP" + to_string(number));
        }
        else if(bIndex.type == "IDENTIFIER") {
            setReg(to_string(bIndex.memory),1);
            memToReg(2);
            long long int indexFix = b.memory - b.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(2);
            setReg(to_string(a.memory),1);
            memToReg(3);

            setReg("0",8);
            long long int number = asmStack.size();
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("JODD C " + to_string(number + 3));
            pushCmd("JUMP" + to_string(number + 4));
            pushCmd("ADD H B");
            pushCmd("ADD B B");
            pushCmd("HALF C");
            pushCmd("JUMP" + to_string(number));
        }
    }
    else if(a.type == "ARRAY" && b.type == "IDENTIFIER") {
        if(aIndex.type == "NUMBER") {
            long long int addr = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addr),1);
            memToReg(3);
            setReg(to_string(b.memory),1);
            memToReg(2);

            setReg("0",8);
            long long int number = asmStack.size();
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("JODD C " + to_string(number + 3));
            pushCmd("JUMP" + to_string(number + 4));
            pushCmd("ADD H B");
            pushCmd("ADD B B");
            pushCmd("HALF C");
            pushCmd("JUMP" + to_string(number));
        }
        else if(aIndex.type == "IDENTIFIER") {
            setReg(to_string(aIndex.memory),1);
            memToReg(2);

            long long int indexFix = a.memory - a.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(3);
            setReg(to_string(b.memory),1);
            memToReg(2);

            setReg("0",8);
            long long int number = asmStack.size();
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("JODD C " + to_string(number + 3));
            pushCmd("JUMP" + to_string(number + 4));
            pushCmd("ADD H B");
            pushCmd("ADD B B");
            pushCmd("HALF C");
            pushCmd("JUMP" + to_string(number));
        }
    }
    else if(a.type == "ARRAY" && b.type == "ARRAY") {
        if(aIndex.type == "NUMBER" && bIndex.type == "NUMBER") {
            long long int addrA = a.memory + stoll(aIndex.name) - a.move + 1;
            long long int addrB = b.memory + stoll(bIndex.name) - b.move + 1;
            setReg(to_string(addrA),1);
            memToReg(2);
            setReg(to_string(addrB),1);
            memToReg(3);

            setReg("0",8);
            long long int number = asmStack.size();
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("JODD C " + to_string(number + 3));
            pushCmd("JUMP" + to_string(number + 4));
            pushCmd("ADD H B");
            pushCmd("ADD B B");
            pushCmd("HALF C");
            pushCmd("JUMP" + to_string(number));
            removeIdef(aIndex.name);
            removeIdef(bIndex.name);
        }
        else if(aIndex.type == "NUMBER" && bIndex.type == "IDENTIFIER") {
            long long int addrA = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addrA),1);
            memToReg(3);
            setReg(to_string(bIndex.memory),1);
            memToReg(2);
            long long int indexFix = b.memory - b.move + 1;
            setReg(to_string(indexFix),4);
            if(indexFix<0){
              pushCmd("SUB B D");
            }else{
              pushCmd("ADD B D");
            }
            pushCmd("COPY A B");
            memToReg(2);

            setReg("0",8);
            long long int number = asmStack.size();
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("JODD C " + to_string(number + 3));
            pushCmd("JUMP" + to_string(number + 4));
            pushCmd("ADD H B");
            pushCmd("ADD B B");
            pushCmd("HALF C");
            pushCmd("JUMP" + to_string(number));
            removeIdef(aIndex.name);
        }
        else if(aIndex.type == "IDENTIFIER" && bIndex.type == "NUMBER") {
          long long int addrB = b.memory + stoll(bIndex.name) - b.move + 1;
          setReg(to_string(addrB),1);
          memToReg(2);
          setReg(to_string(aIndex.memory),1);
          memToReg(8);
          long long int indexFix = a.memory - a.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB H C");
          }else{
            pushCmd("ADD H C");
          }
          pushCmd("COPY A H");
          memToReg(3);

          setReg("0",8);
          long long int number = asmStack.size();
          pushCmd("JZERO C " + to_string(number + 7));
          pushCmd("JODD C " + to_string(number + 3));
          pushCmd("JUMP" + to_string(number + 4));
          pushCmd("ADD H B");
          pushCmd("ADD B B");
          pushCmd("HALF C");
          pushCmd("JUMP" + to_string(number));
          removeIdef(bIndex.name);
        }
        else if(aIndex.type == "IDENTIFIER" && bIndex.type == "IDENTIFIER") {
          setReg(to_string(bIndex.memory),1);
          memToReg(2);
          long long int indexFix = b.memory - b.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB B C");
          }else{
            pushCmd("ADD B C");
          }
          pushCmd("COPY A B");
          memToReg(2);

          setReg(to_string(aIndex.memory),1);
          memToReg(3);
          indexFix = a.memory - a.move + 1;
          setReg(to_string(indexFix),4);
          if(indexFix<0){
            pushCmd("SUB C D");
          }else{
            pushCmd("ADD C D");
          }
          pushCmd("COPY A C");
          memToReg(3);

          setReg("0",8);
          long long int number = asmStack.size();
          pushCmd("JZERO C " + to_string(number + 7));
          pushCmd("JODD C " + to_string(number + 3));
          pushCmd("JUMP" + to_string(number + 4));
          pushCmd("ADD H B");
          pushCmd("ADD B B");
          pushCmd("HALF C");
          pushCmd("JUMP" + to_string(number));
        }
    }
}

void div(Idef a, Idef b) {
    if(a.type == "NUMBER" && b.type == "NUMBER") {
        if(stoll(b.name)==0){
          setReg("0",8);
          return;
        }

        long long int val = stoll(a.name) / stoll(b.name);
        setReg(to_string(val),8);
        removeIdef(a.name);
        removeIdef(b.name);
    }
    else if(a.type == "NUMBER" && b.type == "IDENTIFIER") {

        if(stoll(a.name)==0){
          setReg("0",8);
          removeIdef(a.name);
          return;
        }
        if(stoll(a.name)==2){
          setReg(to_string(b.memory),1);
          memToReg(8);
          pushCmd("HALF H");
          removeIdef(a.name);
          return;
        }

        setReg(to_string(b.memory),1);
        memToReg(3);

        setReg(a.name, 2);
        setReg("0", 8);
        long long int number = asmStack.size();

        pushCmd("JZERO C " + to_string(number + 8));
        pushCmd("JZERO B " + to_string(number + 8));
        pushCmd("INC B");
        pushCmd("SUB B C");
        pushCmd("JZERO B " + to_string(number + 8));
        pushCmd("INC H");
        pushCmd("JUMP " + to_string(number+3));
        setReg("0", 8);
        removeIdef(a.name);
    }
    else if(a.type == "IDENTIFIER" && b.type == "NUMBER") {

        if(stoll(b.name) == 0) {
          setReg("0", 8);
          return;
        }

        if(stoll(b.name)==2){
          setReg(to_string(a.memory),1);
          memToReg(8);
          pushCmd("HALF H");
          removeIdef(b.name);
          return;
        }

        setReg(to_string(a.memory),1);
        memToReg(2);
        setReg(b.name, 3);
        setReg("0", 8);

        long long int number = asmStack.size();
        pushCmd("JZERO C " + to_string(number + 8));
        pushCmd("JZERO B " + to_string(number + 8));
        pushCmd("INC B");
        pushCmd("SUB B C");
        pushCmd("JZERO B " + to_string(number + 8));
        pushCmd("INC H");
        pushCmd("JUMP " + to_string(number+3));
        setReg("0", 8);
        removeIdef(b.name);
    }
    else if(a.type == "IDENTIFIER" && b.type == "IDENTIFIER") {

      if(a.name == b.name) {
        setReg("1",8);
        return;
      }

        setReg(to_string(a.memory),1);
        memToReg(2);
        setReg(to_string(b.memory),1);
        memToReg(3);

        setReg("0",8);
        long long int number = asmStack.size();
        pushCmd("JZERO C " + to_string(number + 11));
        pushCmd("COPY D B");
        pushCmd("INC D");
        pushCmd("SUB D C");
        pushCmd("JZERO D " + to_string(number + 11));
        pushCmd("DEC D");
        pushCmd("INC H");
        pushCmd("COPY B D");
        pushCmd("ADD B B");
        pushCmd("ADD C C");
        pushCmd("JUMP " + to_string(number + 1));
    }
}

void divTab(Idef a, Idef b, Idef aIndex, Idef bIndex) {
  if(a.type == "NUMBER" && b.type == "ARRAY") {
      if(bIndex.type == "NUMBER") {

          if(stoll(a.name) == 0) {
            setReg("0", 8);
            return;
          }

          if(stoll(a.name)==2){
            long long int addr = b.memory + stoll(bIndex.name) - b.move + 1;
            setReg(to_string(addr),1);
            memToReg(8);
            pushCmd("HALF H");
            removeIdef(a.name);
            return;
          }

          long long int addr = b.memory + stoll(bIndex.name) - b.move + 1;
          setReg(to_string(addr),1);
          memToReg(2);

          setReg(a.name, 3);

          setReg("0", 8);
          long long int number = asmStack.size();
          pushCmd("JZERO C" + to_string(number + 7));
          pushCmd("INC C");
          pushCmd("SUB C B");
          pushCmd("JZERO C " + to_string(number + 7));
          pushCmd("INC H");
          pushCmd("JUMP " + to_string(number + 2));
          setReg("0", 8);
          removeIdef(a.name);
      }
      else if(bIndex.type == "IDENTIFIER") {

          if(stoll(a.name) == 0) {
            setReg("0", 8);
            return;
          }

          if(stoll(a.name)==2){
            setReg(to_string(bIndex.memory),1);
            memToReg(2);
            long long int indexFix = b.memory - b.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(8);
            pushCmd("HALF H");
            removeIdef(a.name);
            return;
          }

          setReg(to_string(bIndex.memory),1);
          memToReg(2);
          long long int indexFix = b.memory - b.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB B C");
          }else{
            pushCmd("ADD B C");
          }
          pushCmd("COPY A B");
          memToReg(2);

          setReg(a.name, 3);

          setReg("0", 8);
          long long int number = asmStack.size();
          pushCmd("JZERO C" + to_string(number + 7));
          pushCmd("INC C");
          pushCmd("SUB C B");
          pushCmd("JZERO C " + to_string(number + 7));
          pushCmd("INC H");
          pushCmd("JUMP " + to_string(number + 2));
          setReg("0", 8);
          removeIdef(a.name);
      }
  }
  else if(a.type == "ARRAY" && b.type == "NUMBER") {
        if(aIndex.type == "NUMBER") {
            if(stoll(b.name) == 0) {
              setReg("0", 8);
              return;
            }

            long long int addr = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addr),1);
            memToReg(3);

            setReg(b.name, 2);

            if(stoll(b.name)==2){
              long long int addr = a.memory + stoll(aIndex.name) - a.move + 1;
              setReg(to_string(addr),1);
              memToReg(8);
              pushCmd("HALF H");
              removeIdef(b.name);
              return;
            }

            setReg("0", 8);
            long long int number = asmStack.size();
            pushCmd("JZERO C" + to_string(number + 7));
            pushCmd("INC C");
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("INC H");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
            removeIdef(b.name);
        }
        else if(aIndex.type == "IDENTIFIER") {
            if(stoll(b.name) == 0) {
              setReg("0", 8);
              return;
            }

            if(stoll(b.name)==2){
              setReg(to_string(aIndex.memory),1);
              memToReg(2);
              long long int indexFix = a.memory - a.move + 1;
              setReg(to_string(indexFix),3);
              if(indexFix<0){
                pushCmd("SUB B C");
              }else{
                pushCmd("ADD B C");
              }
              pushCmd("COPY A B");
              memToReg(8);
              pushCmd("HALF H");
              removeIdef(b.name);
              return;
            }

            setReg(to_string(aIndex.memory),1);
            memToReg(3);
            long long int indexFix = a.memory - a.move + 1;
            setReg(to_string(indexFix),2);
            if(indexFix<0){
              pushCmd("SUB C B");
            }else{
              pushCmd("ADD C B");
            }
            pushCmd("COPY A C");
            memToReg(3);

            setReg(b.name, 2);

            setReg("0", 8);
            long long int number = asmStack.size();
            pushCmd("JZERO C" + to_string(number + 7));
            pushCmd("INC C");
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("INC H");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
            removeIdef(b.name);
        }
    }
    else if(a.type == "IDENTIFIER" && b.type == "ARRAY") {
        if(bIndex.type == "NUMBER") {
            long long int addr = b.memory + stoll(bIndex.name) - b.move + 1;
            setReg(to_string(addr),1);
            memToReg(2);
            setReg(to_string(a.memory),1);
            memToReg(3);

            setReg("0", 8);
            long long int number = asmStack.size();
            pushCmd("JZERO C" + to_string(number + 7));
            pushCmd("INC C");
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("INC H");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
        }
        else if(bIndex.type == "IDENTIFIER") {
            setReg(to_string(bIndex.memory),1);
            memToReg(2);
            long long int indexFix = b.memory - b.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(2);
            setReg(to_string(a.memory),1);
            memToReg(3);
            setReg("0", 8);
            long long int number = asmStack.size();
            pushCmd("JZERO C" + to_string(number + 7));
            pushCmd("INC C");
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("INC H");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
        }
    }
    else if(a.type == "ARRAY" && b.type == "IDENTIFIER") {
        if(aIndex.type == "NUMBER") {
            long long int addr = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addr),1);
            memToReg(3);
            setReg(to_string(b.memory),1);
            memToReg(2);
            setReg("0", 8);
            long long int number = asmStack.size();
            pushCmd("JZERO C" + to_string(number + 7));
            pushCmd("INC C");
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("INC H");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
        }
        else if(aIndex.type == "IDENTIFIER") {
            setReg(to_string(aIndex.memory),1);
            memToReg(3);

            long long int indexFix = a.memory - a.move + 1;
            setReg(to_string(indexFix),2);
            if(indexFix<0){
              pushCmd("SUB C B");
            }else{
              pushCmd("ADD C B");
            }
            pushCmd("COPY A C");
            memToReg(3);

            setReg(to_string(b.memory),1);
            memToReg(2);

            setReg("0", 8);
            long long int number = asmStack.size();
            pushCmd("JZERO C" + to_string(number + 7));
            pushCmd("INC C");
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("INC H");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
        }
    }
    else if(a.type == "ARRAY" && b.type == "ARRAY") {
        if(aIndex.type == "NUMBER" && bIndex.type == "NUMBER") {
            long long int addrA = a.memory + stoll(aIndex.name) - a.move + 1;
            long long int addrB = b.memory + stoll(bIndex.name) - b.move + 1;
            setReg(to_string(addrA),1);
            memToReg(3);
            setReg(to_string(addrB),1);
            memToReg(2);
            setReg("0", 8);
            long long int number = asmStack.size();
            pushCmd("JZERO C" + to_string(number + 7));
            pushCmd("INC C");
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("INC H");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
            removeIdef(aIndex.name);
            removeIdef(bIndex.name);
        }
        else if(aIndex.type == "NUMBER" && bIndex.type == "IDENTIFIER") {
            long long int addrA = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addrA),1);
            memToReg(3);
            setReg(to_string(bIndex.memory),1);
            memToReg(2);
            long long int indexFix = b.memory - b.move + 1;
            setReg(to_string(indexFix),4);
            if(indexFix<0){
              pushCmd("SUB B D");
            }else{
              pushCmd("ADD B D");
            }
            pushCmd("COPY A B");
            memToReg(2);
            setReg("0", 8);
            long long int number = asmStack.size();
            pushCmd("JZERO C" + to_string(number + 7));
            pushCmd("INC C");
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("INC H");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
            removeIdef(aIndex.name);
        }
        else if(aIndex.type == "IDENTIFIER" && bIndex.type == "NUMBER") {
          long long int addrB = b.memory + stoll(bIndex.name) - b.move + 1;
          setReg(to_string(addrB),1);
          memToReg(2);
          setReg(to_string(aIndex.memory),1);
          memToReg(8);
          long long int indexFix = a.memory - a.move + 1;
          setReg(to_string(indexFix),4);
          if(indexFix<0){
            pushCmd("SUB H D");
          }else{
            pushCmd("ADD H D");
          }
          pushCmd("COPY A H");
          memToReg(3);
          setReg("0", 8);
          long long int number = asmStack.size();
          pushCmd("JZERO C" + to_string(number + 7));
          pushCmd("INC C");
          pushCmd("SUB C B");
          pushCmd("JZERO C " + to_string(number + 7));
          pushCmd("INC H");
          pushCmd("JUMP " + to_string(number + 2));
          setReg("0", 8);
          removeIdef(bIndex.name);
        }
        else if(aIndex.type == "IDENTIFIER" && bIndex.type == "IDENTIFIER") {
          setReg(to_string(bIndex.memory),1);
          memToReg(2);
          long long int indexFix = b.memory - b.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB B C");
          }else{
            pushCmd("ADD B C");
          }
          pushCmd("COPY A B");
          memToReg(2);

          setReg(to_string(aIndex.memory),1);
          memToReg(3);
          indexFix = a.memory - a.move + 1;
          setReg(to_string(indexFix),4);
          if(indexFix<0){
            pushCmd("SUB C D");
          }else{
            pushCmd("ADD C D");
          }
          pushCmd("COPY A C");
          memToReg(3);

          setReg("0", 8);
          long long int number = asmStack.size();
          pushCmd("JZERO C" + to_string(number + 7));
          pushCmd("INC C");
          pushCmd("SUB C B");
          pushCmd("JZERO C " + to_string(number + 7));
          pushCmd("INC H");
          pushCmd("JUMP " + to_string(number + 2));
          setReg("0", 8);
        }
    }
}

void mod(Idef a, Idef b) {
    if(a.type == "NUMBER" && b.type == "NUMBER") {
        if(stoll(b.name)==0){
          setReg("0",8);
          return;
        }

        long long int val = stoll(a.name) % stoll(b.name);
        setReg(to_string(val),8);
        removeIdef(a.name);
        removeIdef(b.name);
    }
    else if(a.type == "NUMBER" && b.type == "IDENTIFIER") {

        if(stoll(a.name) == 0) {
          setReg("0", 8);
          return;
        }

        setReg(a.name, 2);

        setReg(to_string(b.memory),1);
        memToReg(3);

        pushCmd("COPY H B");
        pushCmd("INC B");
        long long int number = asmStack.size();
        pushCmd("JZERO C " + to_string(number + 6));
        pushCmd("JZERO B " + to_string(number + 6));
        pushCmd("SUB B C");
        pushCmd("JZERO B " + to_string(number + 7));
        pushCmd("COPY H B");
        pushCmd("JUMP " + to_string(number + 2));
        setReg("0", 8);
        pushCmd("DEC H");

        removeIdef(a.name);
    }
    else if(a.type == "IDENTIFIER" && b.type == "NUMBER") {
        if(stoll(b.name) == 0) {
          setReg("0", 8);
          return;
        }
        if(stoll(b.name) == 2) {
          setReg(to_string(a.memory),1);
          memToReg(2);
          pushCmd("INC B");
          pushCmd("SUB H H");
          long long int number = asmStack.size();
          pushCmd("JODD B "+ to_string(number + 2));
          pushCmd("INC H");
          return;
        }

        setReg(to_string(a.memory),1);
        memToReg(2);
        setReg(b.name, 3);

        pushCmd("COPY H B");
        pushCmd("INC B");
        long long int number = asmStack.size();
        pushCmd("JZERO C " + to_string(number + 6));
        pushCmd("JZERO B " + to_string(number + 6));
        pushCmd("SUB B C");
        pushCmd("JZERO B " + to_string(number + 7));
        pushCmd("COPY H B");
        pushCmd("JUMP " + to_string(number + 2));
        setReg("0", 8);
        pushCmd("DEC H");

        removeIdef(b.name);
    }
    else if(a.type == "IDENTIFIER" && b.type == "IDENTIFIER") {
        setReg(to_string(a.memory),1);
        memToReg(2);
        setReg(to_string(b.memory),1);
        memToReg(3);

        if(a.name == b.name) {
          setReg("0",8);
          return;
        }

        pushCmd("COPY H B");
        pushCmd("INC B");
        long long int number = asmStack.size();
        pushCmd("JZERO C " + to_string(number + 6));
        pushCmd("JZERO B " + to_string(number + 6));
        pushCmd("SUB B C");
        pushCmd("JZERO B " + to_string(number + 7));
        pushCmd("COPY H B");
        pushCmd("JUMP " + to_string(number + 2));
        setReg("0", 8);
        pushCmd("DEC H");
    }
}

void modTab(Idef a, Idef b, Idef aIndex, Idef bIndex) {
  if(a.type == "NUMBER" && b.type == "ARRAY") {
      if(bIndex.type == "NUMBER") {

          if(stoll(a.name) == 0) {
            setReg("0", 8);
            return;
          }

          long long int addr = b.memory + stoll(bIndex.name) - b.move + 1;
          setReg(to_string(addr),1);
          memToReg(2);

          setReg(a.name, 3);

          pushCmd("COPY H C");
          pushCmd("INC C");
          long long int number = asmStack.size();
          pushCmd("JZERO B " + to_string(number + 6));
          pushCmd("JZERO C " + to_string(number + 6));
          pushCmd("SUB C B");
          pushCmd("JZERO C " + to_string(number + 7));
          pushCmd("COPY H C");
          pushCmd("JUMP " + to_string(number + 2));
          setReg("0", 8);
          pushCmd("DEC H");
          removeIdef(a.name);
      }
      else if(bIndex.type == "IDENTIFIER") {

          if(stoll(a.name) == 0) {
            setReg("0", 8);
            return;
          }

          setReg(to_string(bIndex.memory),1);
          memToReg(2);
          long long int indexFix = b.memory - b.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB B C");
          }else{
            pushCmd("ADD B C");
          }
          pushCmd("COPY A B");
          memToReg(2);

          setReg(a.name, 3);

          pushCmd("COPY H C");
          pushCmd("INC C");
          long long int number = asmStack.size();
          pushCmd("JZERO B " + to_string(number + 6));
          pushCmd("JZERO C " + to_string(number + 6));
          pushCmd("SUB C B");
          pushCmd("JZERO C " + to_string(number + 7));
          pushCmd("COPY H C");
          pushCmd("JUMP " + to_string(number + 2));
          setReg("0", 8);
          pushCmd("DEC H");
          removeIdef(a.name);
      }
  }
  else if(a.type == "ARRAY" && b.type == "NUMBER") {
        if(aIndex.type == "NUMBER") {
            if(stoll(b.name) == 0) {
              setReg("0", 8);
              return;
            }

            if(stoll(b.name) == 2) {
              long long int addr = a.memory + stoll(aIndex.name) - a.move + 1;
              setReg(to_string(addr),1);
              memToReg(2);
              pushCmd("INC B");
              pushCmd("SUB H H");
              long long int number = asmStack.size();
              pushCmd("JODD B "+ to_string(number + 2));
              pushCmd("INC H");
              return;
            }

            long long int addr = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addr),1);
            memToReg(3);

            setReg(b.name, 2);

            pushCmd("COPY H C");
            pushCmd("INC C");
            long long int number = asmStack.size();
            pushCmd("JZERO B " + to_string(number + 6));
            pushCmd("JZERO C " + to_string(number + 6));
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("COPY H C");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
            pushCmd("DEC H");
            removeIdef(b.name);
        }
        else if(aIndex.type == "IDENTIFIER") {
            if(stoll(b.name) == 0) {
              setReg("0", 8);
              return;
            }

            if(stoll(b.name) == 2) {
              setReg(to_string(aIndex.memory),1);
              memToReg(3);
              long long int indexFix = a.memory - a.move + 1;
              setReg(to_string(indexFix),2);
              if(indexFix<0){
                pushCmd("SUB C B");
              }else{
                pushCmd("ADD C B");
              }
              pushCmd("COPY A C");
              memToReg(2);
              pushCmd("INC B");
              pushCmd("SUB H H");
              long long int number = asmStack.size();
              pushCmd("JODD B "+ to_string(number + 2));
              pushCmd("INC H");
              return;
            }

            setReg(to_string(aIndex.memory),1);
            memToReg(3);
            long long int indexFix = a.memory - a.move + 1;
            setReg(to_string(indexFix),2);
            if(indexFix<0){
              pushCmd("SUB C B");
            }else{
              pushCmd("ADD C B");
            }
            pushCmd("COPY A C");
            memToReg(3);

            setReg(b.name, 2);

            pushCmd("COPY H C");
            pushCmd("INC C");
            long long int number = asmStack.size();
            pushCmd("JZERO B " + to_string(number + 6));
            pushCmd("JZERO C " + to_string(number + 6));
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("COPY H C");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
            pushCmd("DEC H");
            removeIdef(b.name);
        }
    }
    else if(a.type == "IDENTIFIER" && b.type == "ARRAY") {
        if(bIndex.type == "NUMBER") {
            long long int addr = b.memory + stoll(bIndex.name) - b.move + 1;
            setReg(to_string(addr),1);
            memToReg(2);
            setReg(to_string(a.memory),1);
            memToReg(3);

            pushCmd("COPY H C");
            pushCmd("INC C");
            long long int number = asmStack.size();
            pushCmd("JZERO B " + to_string(number + 6));
            pushCmd("JZERO C " + to_string(number + 6));
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("COPY H C");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
            pushCmd("DEC H");
        }
        else if(bIndex.type == "IDENTIFIER") {
            setReg(to_string(bIndex.memory),1);
            memToReg(2);
            long long int indexFix = b.memory - b.move + 1;
            setReg(to_string(indexFix),3);
            if(indexFix<0){
              pushCmd("SUB B C");
            }else{
              pushCmd("ADD B C");
            }
            pushCmd("COPY A B");
            memToReg(2);
            setReg(to_string(a.memory),1);
            memToReg(3);
            pushCmd("COPY H C");
            pushCmd("INC C");
            long long int number = asmStack.size();
            pushCmd("JZERO B " + to_string(number + 6));
            pushCmd("JZERO C " + to_string(number + 6));
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("COPY H C");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
            pushCmd("DEC H");
        }
    }
    else if(a.type == "ARRAY" && b.type == "IDENTIFIER") {
        if(aIndex.type == "NUMBER") {
            long long int addr = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addr),1);
            memToReg(3);
            setReg(to_string(b.memory),1);
            memToReg(2);
            pushCmd("COPY H C");
            pushCmd("INC C");
            long long int number = asmStack.size();
            pushCmd("JZERO B " + to_string(number + 6));
            pushCmd("JZERO C " + to_string(number + 6));
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("COPY H C");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
            pushCmd("DEC H");
        }
        else if(aIndex.type == "IDENTIFIER") {
            setReg(to_string(aIndex.memory),1);
            memToReg(3);

            long long int indexFix = a.memory - a.move + 1;
            setReg(to_string(indexFix),2);
            if(indexFix<0){
              pushCmd("SUB C B");
            }else{
              pushCmd("ADD C B");
            }
            pushCmd("COPY A C");
            memToReg(3);

            setReg(to_string(b.memory),1);
            memToReg(2);

            pushCmd("COPY H C");
            pushCmd("INC C");
            long long int number = asmStack.size();
            pushCmd("JZERO B " + to_string(number + 6));
            pushCmd("JZERO C " + to_string(number + 6));
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("COPY H C");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
            pushCmd("DEC H");
        }
    }
    else if(a.type == "ARRAY" && b.type == "ARRAY") {
        if(aIndex.type == "NUMBER" && bIndex.type == "NUMBER") {
            long long int addrA = a.memory + stoll(aIndex.name) - a.move + 1;
            long long int addrB = b.memory + stoll(bIndex.name) - b.move + 1;
            setReg(to_string(addrA),1);
            memToReg(3);
            setReg(to_string(addrB),1);
            memToReg(2);
            pushCmd("COPY H C");
            pushCmd("INC C");
            long long int number = asmStack.size();
            pushCmd("JZERO B " + to_string(number + 6));
            pushCmd("JZERO C " + to_string(number + 6));
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("COPY H C");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
            pushCmd("DEC H");
            removeIdef(aIndex.name);
            removeIdef(bIndex.name);
        }
        else if(aIndex.type == "NUMBER" && bIndex.type == "IDENTIFIER") {
            long long int addrA = a.memory + stoll(aIndex.name) - a.move + 1;
            setReg(to_string(addrA),1);
            memToReg(3);
            setReg(to_string(bIndex.memory),1);
            memToReg(2);
            long long int indexFix = b.memory - b.move + 1;
            setReg(to_string(indexFix),4);
            if(indexFix<0){
              pushCmd("SUB B D");
            }else{
              pushCmd("ADD B D");
            }
            pushCmd("COPY A B");
            memToReg(2);
            pushCmd("COPY H C");
            pushCmd("INC C");
            long long int number = asmStack.size();
            pushCmd("JZERO B " + to_string(number + 6));
            pushCmd("JZERO C " + to_string(number + 6));
            pushCmd("SUB C B");
            pushCmd("JZERO C " + to_string(number + 7));
            pushCmd("COPY H C");
            pushCmd("JUMP " + to_string(number + 2));
            setReg("0", 8);
            pushCmd("DEC H");
            removeIdef(aIndex.name);
        }
        else if(aIndex.type == "IDENTIFIER" && bIndex.type == "NUMBER") {
          long long int addrB = b.memory + stoll(bIndex.name) - b.move + 1;
          setReg(to_string(addrB),1);
          memToReg(2);
          setReg(to_string(aIndex.memory),1);
          memToReg(8);
          long long int indexFix = a.memory - a.move + 1;
          setReg(to_string(indexFix),4);
          if(indexFix<0){
            pushCmd("SUB H D");
          }else{
            pushCmd("ADD H D");
          }
          pushCmd("COPY A H");
          memToReg(3);
          pushCmd("COPY H C");
          pushCmd("INC C");
          long long int number = asmStack.size();
          pushCmd("JZERO B " + to_string(number + 6));
          pushCmd("JZERO C " + to_string(number + 6));
          pushCmd("SUB C B");
          pushCmd("JZERO C " + to_string(number + 7));
          pushCmd("COPY H C");
          pushCmd("JUMP " + to_string(number + 2));
          setReg("0", 8);
          pushCmd("DEC H");
          removeIdef(bIndex.name);
        }
        else if(aIndex.type == "IDENTIFIER" && bIndex.type == "IDENTIFIER") {
          setReg(to_string(bIndex.memory),1);
          memToReg(2);
          long long int indexFix = b.memory - b.move + 1;
          setReg(to_string(indexFix),3);
          if(indexFix<0){
            pushCmd("SUB B C");
          }else{
            pushCmd("ADD B C");
          }
          pushCmd("COPY A B");
          memToReg(2);

          setReg(to_string(aIndex.memory),1);
          memToReg(3);
          indexFix = a.memory - a.move + 1;
          setReg(to_string(indexFix),4);
          if(indexFix<0){
            pushCmd("SUB C D");
          }else{
            pushCmd("ADD C D");
          }
          pushCmd("COPY A C");
          memToReg(3);

          pushCmd("COPY H C");
          pushCmd("INC C");
          long long int number = asmStack.size();
          pushCmd("JZERO B " + to_string(number + 6));
          pushCmd("JZERO C " + to_string(number + 6));
          pushCmd("SUB C B");
          pushCmd("JZERO C " + to_string(number + 7));
          pushCmd("COPY H C");
          pushCmd("JUMP " + to_string(number + 2));
          setReg("0", 8);
          pushCmd("DEC H");
        }
    }
}
