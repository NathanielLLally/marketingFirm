#!/usr/bin/perl
use warnings;

use Net::DNS::Async::Simple;
#use Test::More;
#my $list = [
#    {   query => ['www.realms.org','A'],
#    },{ query => ['174.136.1.7','PTR'],
#        nameServers => ['8.8.4.4','4.2.2.2']
#    }
#];
#Net::DNS::Async::Simple::massDNSLookup($list);
#ok $list->[0]->{address} eq '174.136.1.7', 'forward lookup worked';
#ok $list->[1]->{ptrdname} eq 'tendotfour.realms.org', 'reverse lookup worked';

use Data::Dumper;

my $file = shift @ARGV;
my $FD = *STDIN;

if (defined $file and -e "$file") {
  open($FD, "<$file") || die "cannot open $file";
} 

#print Dumper $adns->synchronous("www.google.com", ADNS_R_A);

my $n = 0;
my $list = [];
while (<$FD>) {
  chomp;
  push @$list, { query => [$_, 'A'], nameServers => ['8.8.8.8', '8.8.4.4'] };
}

Net::DNS::Async::Simple::massDNSLookup($list);
foreach my $el (@$list) {
  if (exists $el->{address}) {
    print $el->{name}."\n";
  }
}

