#!/usr/bin/perl
package main;
use warnings;
use strict;
use DBI;
use DBD::CSV;
use IPC::Run qw( run timeout );
use LWP;
use LWP::Parallel;
use HTTP::Request;
use URI::Encode;
use URI::Escape;
use Storable qw(retrieve store thaw freeze nfreeze);
#use Data::Serializer;
use JSON;
use Carp qw(croak cluck longmess shortmess);
use Data::Dumper;


sub runCmd($$;$) {
  my ($cmd, $in, $key) = @_;
  if (not defined $key) {
    $key = "key";
  }

  my ($out, $err);
  my @cmd = split(/ /,$cmd);

  run \@cmd, $in, \$out, \$err, timeout( 10 ) or croak "$cmd: $?";

  #  return join(@$out);

  return $out;
}

my ($dbh, @headers);
my ($cities, $categories, @url);

#my $DSN = 'driver={};server=$server_name;database=$database_name;uid=$database_user;pwd=$database_pass;';

#
#  combinitorics of categpories by cities
#
####################################################3
$dbh = DBI->connect("dbi:CSV:", undef, undef, {
    f_ext => ".csv/r",
    RaiseError => 1,
  }) or die "cannot connect: $DBI::errstr";

#        # Simple statements
#        $dbh->do ("CREATE TABLE foo (id INTEGER, name CHAR (10))");

my $filename = $ARGV[0];
$filename =~ s/\.csv//;
my $sth = $dbh->prepare ("select website from $filename as csv where char_length(csv.website) > 0");
$sth->execute;
$categories = $sth->fetchall_arrayref({});

print Dumper(\$categories);

print $#{$categories};
