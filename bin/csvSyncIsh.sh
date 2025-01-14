#!/bin/sh

cat out.csv | cperl 'my @o = split(",", $_); print $o[7]."\n";' | grep "http" | parseURL.pl --output=fqdn | dnsResolver.pl > fqdnlist.resolved

#Outbound Domains
#Compare outbound links of up to 5 domains.

curl https://data.domainrank.io/outbound_domains? 
