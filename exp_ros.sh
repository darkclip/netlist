#!/usr/bin/env bash

./netgen.py ref/china.txt -o target/china.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_China\n'
./netgen.py ref/china6.txt -o target/china6.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_China\n'

./netgen.py ref/chinanet.txt -o target/telecom.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_ChinaTelecom\n'
./netgen.py ref/chinanet6.txt -o target/telecom6.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_ChinaTelecom\n'

./netgen.py ref/unicom.txt -o target/unicom.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_ChinaUnicom\n'
./netgen.py ref/unicom6.txt -o target/unicom6.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_ChinaUnicom\n'

./netgen.py ref/china.txt -e ref/chinanet.txt ref/unicom.txt -o target/others.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_ChinaOthers\n'
./netgen.py ref/china6.txt -e ref/chinanet6.txt ref/unicom6.txt -o target/others6.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_ChinaOthers\n'

./netgen.py 0.0.0.0/0 -e private.txt ref/china.txt -o target/foreign.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_Foreign\n'
./netgen.py ::/0 -e private6.txt ref/china6.txt -o target/foreign6.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_Foreign\n'

./netgen.py private.txt -o target/private.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_Private\n'
./netgen.py private6.txt -o target/private6.rsc -p '/routing rule add dst-address=' -s $' action=lookup table=Route_Private\n'
