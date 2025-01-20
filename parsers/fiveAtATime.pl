#!/usr/bin/perl -w

use strict;

my $file = shift @ARGV;
my $FD = *STDIN;

if (defined $file and -e "$file") {
  open($FD, "<$file") || die "cannot open $file";
}

my @domain;
my $url = "https://data.domainrank.io/outbound_domains?";

while (<$FD>) {
  chomp;
  push @domain, $_;
  if ($#domain == 4) {
    my $query = join("&", map { "domain=$_" } @domain);
    print "$url$query\n";
    @domain = ();
  }
}
