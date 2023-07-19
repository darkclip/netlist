#!/usr/bin/env bash

./netgen.py ip-lists/china.txt -o net/china.txt
./netgen.py ip-lists/china6.txt -o net/china6.txt

./netgen.py ip-lists/chinanet.txt -o net/telecom.txt
./netgen.py ip-lists/chinanet6.txt -o net/telecom6.txt

./netgen.py ip-lists/unicom.txt -o net/unicom.txt
./netgen.py ip-lists/unicom6.txt -o net/unicom6.txt

./netgen.py ip-lists/china.txt -e ip-lists/chinanet.txt ip-lists/unicom.txt -o net/others.txt
./netgen.py ip-lists/china6.txt -e ip-lists/chinanet6.txt ip-lists/unicom6.txt -o net/others6.txt

./netgen.py 0.0.0.0/0 -e private.txt ip-lists/china.txt -o net/foreign.txt
./netgen.py ::/0 -e private6.txt ip-lists/china6.txt -o net/foreign6.txt

./netgen.py private.txt -o net/private.txt
./netgen.py private6.txt -o net/private6.txt
