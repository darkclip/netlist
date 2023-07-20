#!/usr/bin/env bash

./raydata.py dat-release/geoip.dat -c cn -o mosdns/chinaip.txt geoip
./raydata.py dat-release/geosite.dat -c cn -o mosdns/chinasite.txt geosite --formatter format_mosdns.json
