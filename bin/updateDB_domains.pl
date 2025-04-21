#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use feature 'isa';

use DBI;
use Data::Dumper;
use List::Util qw(shuffle);
use Try::Tiny;
use Config::Tiny;
use File::Basename;
use File::Spec;
use Try::Tiny;
use Role::Tiny;
use lib "/home/nathaniel/src/git/marketingFirm/lib";
use ParsePURI;
use Email::Address;

my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($dirname, '..','etc','obiseo.conf');
print "using config $cfgFile\n";
our $CFG = Config::Tiny->read( $cfgFile );

print `date`;

my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

my $sth = $dbh->prepare ("select url from urls ");
$sth->execute();

my $rs = $sth->fetchall_arrayref({});

foreach my $row (@$rs) {
  my $p = ParsePURI->new();
  my $d = $p->parse($row->{url});
  my $domain = $p->first->{domain};
  my $sth = $dbh->prepare ("insert into domain (domain) values (?) on conflict do nothing");
  $sth->execute($domain);
  my $sth = $dbh->prepare ("update urls set did = (select id from domain where domain = ?) where url = ?");
  $sth->execute($domain,$row->{url});
  $sth->finish;
}



