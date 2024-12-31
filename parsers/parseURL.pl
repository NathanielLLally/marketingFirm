#!/usr/bin/perl

use URI::Find;
use URI;
#use URI::Info;
use Data::Dumper;

use warnings;
use strict;

local $/;
undef $/;

my $file = <STDIN>;
my %url;

#my $uriInfo = URI::Info->new();
my $finder = URI::Find->new(
        sub {
            my ($uri) = shift;
            #            my $u = URI->new(
            #            my $nfo = $uriInfo->info($uri); 
            $uri =~ /(.*?)\,/;
            print "$1\n";

            $url{$1}++;
            #            $url{$nfo->host}++;
            #            print $nfo->host."\n";
        }
);

my $count = $finder->find(\$file);

print "found $count\n";

foreach my $k(keys %url) {
  print "$k\n";
}

