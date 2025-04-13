#!/usr/bin/perl
use warnings;

use Net::ADNS qw(ADNS_R_A ADNS_R_MX);
$adns = Net::ADNS->new;
use Data::Dumper;

my $file = shift @ARGV;
my $FD = *STDIN;

if (defined $file and -e "$file") {
  open($FD, "<$file") || die "cannot open $file";
} 

#print Dumper $adns->synchronous("www.google.com", ADNS_R_A);

my $n = 0;
while (<$FD>) {
  print "submit $_ $n\n";
  $query = $adns->submit("$_", ADNS_R_A);
  $query->{user} = $n++;
}

my ($r, $w, $e, $t) = $adns->before_select;
while (select($r, $w, $e, 1)) {
  printf("%s %s %s\n", $r, $w, $e);
  if (my $answer = $adns->check) {
    print Dumper(\$answer);
    my $uri = $answer->{owner};
    my ($host,$domain) = ((undef) x 2);
    if ($uri =~ /(.*?)?\.?(\w+\.\w+)$/) {
      ($host,$domain) = ($1,$2);
      print "$uri\n\t$host\n\t$domain\n\n";
    }
  }
  print ".\n";
}

