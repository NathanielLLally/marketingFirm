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
    f_dir => 'data',
    RaiseError => 1,
  }) or die "cannot connect: $DBI::errstr";

#        # Simple statements
#        $dbh->do ("CREATE TABLE foo (id INTEGER, name CHAR (10))");

no warnings;
my ($filename,$file2) = @ARGV;

unless (-e "data/$filename and -e data/$file2) {
  print "[src .csv] [dst .csv] | tee output\n";
  print "will not modify destination csv \n\n";
  exit;
}
use warnings;
$filename =~ s/\.csv//;
$file2 =~ s/\.csv//;

my (%uniq,%u,%emailBySite);
#$uniq{$categories->{email}} = $categories->{website};

#
#  crawled emails
#
my $sth = $dbh->prepare ("select email,website from $filename as csv where char_length(csv.website) > 0");
$sth->execute;
$categories = $sth->fetchall_arrayref({});

#last out first in
foreach my $el (@$categories) {
  $el->{email} =~ s/\/$//;
  my $site = $el->{website};
  if (defined $site) {
    $site =~ s/https?:\/\///;
    $site =~ s/\/.*//;
    $uniq{$el->{email}} = $site;
  }
}

foreach my $email (keys %uniq) {
  $emailBySite{$uniq{$email}} = $email;
  #print "$email,".$uniq{$email}."\n";
}

#  yellow pages info
#
$sth = $dbh->prepare ("select * from $file2 as csv where char_length(csv.website) > 0");
$sth->execute;
$categories = $sth->fetchall_arrayref({});

open(UNION, ">union.csv") || die "no write cur dir";
open(PHONE, ">phone.csv") || die "no write cur dir";
open(SITE, ">website.csv") || die "no write cur dir";


foreach my $el (@$categories) {
  my $site = $el->{website};
  if (defined $site) {
    $site =~ s/https?:\/\///;
    $site =~ s/\/.*//;
    print "$site\n";
  }

  if (defined $site and exists $emailBySite{$site}) {
    print "$site\n";
    $el->{email} = $emailBySite{$site};
    print SITE join(',',map { $el->{$_} } sort keys %$el)."\n";
  } else {
    print PHONE join(',',map { $el->{$_} } sort keys %$el)."\n";
  }
  print UNION join(',',map { $el->{$_} } sort keys %$el)."\n";
}
#union -> array
#$u{$categories->{email}} = ();

#try to pick right "one"
#$categories->{website};

#  $emailBySite{$uniq{$email}} = $email;

close(UNION);
close(PHONE);
close(SITE);
