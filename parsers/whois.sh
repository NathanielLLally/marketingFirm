#!/bin/sh

for i in `cat urllist | parseURL.pl --output domain`; do echo $i; whois $i | grep -i email; echo ""; done
