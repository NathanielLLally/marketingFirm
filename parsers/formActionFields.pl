#!/usr/bin/perl -w
use strict;

my $file = shift @ARGV;
open(OUT, ">out.csv") || die "fix perms";
print OUT "Name,Phone,Email,Message\n";

my $FD = *STDIN;

if (defined $file and -e "$file") {
  open($FD, "<$file") || die "cannot open $file";
} 

my $re = qr/contact_name=(.*?)&contact_phone=(.*?)&contact_email=(.*?)&contact_message=(.*?)&/;
while (<$FD>) {
  if ($_ =~ /$re/) {
    my @line = ($1,$2,$3,$4);
    print $_;
    print OUT join(',', map {"\"$_\""} @line) . "\n";
  }
}


close OUT;
close $FD;
