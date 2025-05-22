#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use feature 'isa';

use DBI;
use Data::Dumper;
use List::Util qw(shuffle);
use Config::Tiny;
use File::Basename;
use File::Spec;
use Try::Tiny;
use Role::Tiny;

my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($dirname, '..','etc','obiseo.conf');
print "using config $cfgFile\n";
our $CFG = Config::Tiny->read( $cfgFile );

print `date`;

my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

my $file = shift @ARGV;
my $yyyymm;
if ($file =~ /DR([\d]{6})top1m.csv/) {
  $yyyymm = $1;
} else {
  die "wrong file";
}

my $rank = 1;
  open(FH, "<$file") || die "cannot open html [$file]!\n";
  while (<FH>) {
    chomp;
    if ($_ =~ /\./) {
      my $domain = $_;
      my $sth = $dbh->prepare ("insert into drtopmil (rank,domain,yyyymm) values (?,?,?)");
      $sth->execute($rank++, $domain, $yyyymm);
      $sth->finish;
    }
  }
  close FH;


