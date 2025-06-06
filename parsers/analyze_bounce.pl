#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;

my %mta;
my $file = shift @ARGV;
my $email = { File => $file };

my $header = "";
my %want = (
	'Original-Recipient' => 1,
	'Final-Recipient' => 1,
	'Reporting-MTA' => 1,
	'Diagnostic-Code' => 1,
	'Remote-MTA' => 1,
);

open(FILE, "<$file") || die "cannot open $file";
while (<FILE>) {
	#	chomp;
	if ($_ =~ /^([\w\-]+):/) {
		$header = $1;
	}
	if (exists $want{$header}) {
		$_ =~ s/^.*?: //;
		$_ =~ s/\s+$/ /;
		$_ =~ s/^\s+/ /;
		$email->{$header} .= lc $_;
	}
	#$mta{lc($_)}++;
	#	print "$header\n" if (length $header);
}
close(FILE);


my @out = map { "$_ => ".$email->{$_}; } (sort keys %$email);
print "{".join('|',@out)."}\n";

#exit;

#foreach my $k (sort { $mta{$a} <=> $mta{$b} } keys %mta) {
#	my $v = $mta{$k};
#	print "$k => $v\n";
#}

