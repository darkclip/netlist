#!/usr/bin/env bash

./netgen.py ip-lists/china.txt -o ros/china.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_China\n'
./netgen.py ip-lists/china6.txt -o ros/china6.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_China\n'

./netgen.py ip-lists/chinanet.txt -o ros/telecom.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_ChinaTelecom\n'
./netgen.py ip-lists/chinanet6.txt -o ros/telecom6.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_ChinaTelecom\n'

./netgen.py ip-lists/unicom.txt -o ros/unicom.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_ChinaUnicom\n'
./netgen.py ip-lists/unicom6.txt -o ros/unicom6.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_ChinaUnicom\n'

./netgen.py ip-lists/china.txt -e ip-lists/chinanet.txt ip-lists/unicom.txt -o ros/others.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_ChinaOthers\n'
./netgen.py ip-lists/china6.txt -e ip-lists/chinanet6.txt ip-lists/unicom6.txt -o ros/others6.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_ChinaOthers\n'

./netgen.py 0.0.0.0/0 -e private.txt ip-lists/china.txt -o ros/foreign.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_Foreign\n'
./netgen.py ::/0 -e private6.txt ip-lists/china6.txt -o ros/foreign6.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_Foreign\n'

./netgen.py private.txt -o ros/private.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_Private\n'
./netgen.py private6.txt -o ros/private6.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_Private\n'
