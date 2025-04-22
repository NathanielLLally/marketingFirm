#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Net::SMTP;
use DBI;
use Data::Dumper;
use Net::DNS::Async;
use URI::Encode;
use AnyEvent;
use AnyEvent::DNS;
use AnyEvent::SMTP;
use Net::SMTP;

my $cv = AnyEvent->condvar;


my $uri     = URI::Encode->new( { encode_reserved => 0 } );
my $c = new Net::DNS::Async(QueueSize => 20, Retries => 3);


my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=127.0.0.1", 'postgres', undef, {
      RaiseError => 1,
      InactiveDestroy => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

my $sth = $dbh->prepare ("select email from mx.pending where random() < 0.01 limit 1");
#my $sth = $dbh->prepare ("select email,name,website,uuid from test_pending_email where sent is null");

$sth->execute;
my $batch = $sth->fetchall_arrayref({});

foreach (@$batch) {
  my ($email) = ($uri->decode($_->{email}));
  if ($email =~ /\@(.*)$/) {
    my @parts = reverse split(/\./,$1);
    my $domain = sprintf("%s.%s", $parts[1],$parts[0]);
    $cv->begin;
    AnyEvent::DNS::mx "$domain", sub {
      my @hosts = @_;
      print "mx for $domain\n";
      foreach (@hosts) {
        print "\t$_\n";
        my $smtp = Net::SMTP->new($_);

      }
      $cv->end;
    };
  }
  my $domain;
}

$cv->recv;

$dbh->disconnect;
