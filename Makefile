make:
	bison -d bizon.y -o bizon.c
	flex -o flex.c flex.l
	gcc flex.c bizon.c -lm -lfl -o out -std=c99 -D_BSD_SOURCE
