#!/usr/bin/perl
use warnings;

use Net::ADNS qw(ADNS_R_A ADNS_R_MX);
$adns = Net::ADNS->new;
use Data::Dumper;

my %data;

#nt Dumper $adns->synchronous("www.google.com", ADNS_R_A);
my $query = $adns->submit("www.gmail.com", ADNS_R_A);
$query->{user} = 'my data';


my ($r, $w, $e, $t) = $adns->before_select;


if (select($r, $w, $e, $t)) {
  while (my $answer = $adns->check) {
    my $uri = $answer->{owner};
    my ($host,$domain) = ((undef) x 2);
    if ($uri =~ /(.*?)?\.?(\w+\.\w+)$/) {
      ($host,$domain) = ($1,$2);
      print "$uri\n\t$host\n\t$domain\n\n";
    }
  }
}

