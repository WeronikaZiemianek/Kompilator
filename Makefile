make: bizon.y flex.l
	bison -d bizon.y
	flex flex.l
	g++ -std=c++11 -o compiler lex.yy.c bizon.tab.c -lfl
