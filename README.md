# Kompilator

Autor: Weronika Ziemianek
Indeks: 236711

Kurs: JEZYKI FORMALNE I TECHNIKI TRANSLACJI 2018/2019

Kompilator prostego jezyka imperatywnego do maszyny rejestrowej.

Pliki:
Makefile - plik uruchamiajacy kompilacje projektu
flex.l - plik FLEXa 
bizon.y - plik BISONa, zawiera takze funkcje programu w jezyku C++.

Programy i wersje:
flex 2.6.4
bison (GNU Bison) 3.0.4
gcc 8.2.0 (Ubuntu 8.2.0-7ubuntu1) 

Uzycie:
Kompilacja projektu wykonwana jest poleceniem 'make'.
Program wykonywalny znajduje sie pod nazwa 'compiler'.
Uruchomienie nastepuje za pomoca komendy ./compiler.
Kod zrodlowy czytany jest ze standardowego wyjscia i drukowany do pliku "out". 
( ./compiler out < in).
