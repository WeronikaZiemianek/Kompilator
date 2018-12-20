#!/bin/bash

echo -e "\n======== MakeFile"
make

for filename in Tests/*.txt; do
	echo -e "\n======== " $filename
	./compiler < $filename
done 
