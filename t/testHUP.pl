#!/usr/bin/env perl
#===============================================================================
#
#         FILE: testHUP.pl
#
#        USAGE: ./testHUP.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 01/26/2025 08:51:25 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;

$SIG{HUP} = sub {
	print "hello world\n";
};

print "$$\n";

do {
	sleep 1;
} while(1);
