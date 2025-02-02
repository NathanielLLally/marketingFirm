#!/usr/bin/perl

use strict;
use warnings;
use lib './lib';

use URI::Find;
use URI;
use URI::Encode;
use URI::Escape;
#use URI::Info;
use URI::Simple;
use Data::Dumper;
use Getopt::Long;
use Tie::IxHash;
use ParsePURI;

my %url;
my %urlParts;

my $URI = URI::Encode->new( { encode_reserved => 0 } );

#$SIG{__DIE__} = sub {
#  print "die hook\n";
  #exit;
  #};

my ($Pverbose, $Pcount, $Phelp, $Pfile, @Poutput) = ((undef) x 3, '' x 1);
GetOptions ("count" => \$Pcount, 
  "file=s" => \$Pfile,
  "output=s" => \@Poutput,
  "verbose" => \$Pverbose,
  "help" => \$Phelp
);

if (defined $Phelp) {
 print "output (url,fqdn,query,params,path,scheme,email)\n";
 exit;
}

my $file = $Pfile;
my $FD = *STDIN;

if (defined $file and -e "$file") {
  open($FD, "<$file") || die "cannot open $file";
}

local $/;
undef $/;

my $text = <$FD>;
#print "$text\n";


my $pseudoUniversalResourceIndicator = ParsePURI->new(
	output => \@Poutput,
	verbose => $Pverbose	
);

print Dumper($pseudoUniversalResourceIndicator->parse($text));

#my $c = $pseudoUniversalResourceIndicator->count();
#if ( defined $c );
#  print "found $c\n";
#}
