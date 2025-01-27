#!/usr/bin/env perl
#===============================================================================
#
#         FILE: testBatch.pl
#
#        USAGE: ./testBatch.pl  
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
#      CREATED: 01/25/2025 06:56:20 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use Data::Dumper;


my $array = [1..1000];

my @batch;
while (@batch = splice(@$array,0,10)) {
	printf("batch count: %u, array count: %u, batch values [%s]\n",
			$#batch + 1, $#{$array}, join(",",@batch));
}
