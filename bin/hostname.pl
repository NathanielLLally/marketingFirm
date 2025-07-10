#!/usr/bin/perl
use warnings;
use strict;
use Sys::Hostname;

my $host = hostname();

print "host $host\n";
