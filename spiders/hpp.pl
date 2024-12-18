#!/usr/bin/perl

use strict;

undef $/;
my $f = <STDIN>;

#multipartbounday
# 
$f =~ s/\=\s*?$//gm;
$f =~ s/[\n\r]//gm;
$f =~ s/3D//gm;

print "$f\n";
