#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Net::SMTP;
use DBI;
use Data::Dumper;
#use Net::DNS::Async;
use URI::Encode;
use Net::SMTP;
use Data::Dumper;
use Coro::AnyEvent;
use Parallel::ForkManager;
use Net::DNS;
use Try::Tiny;

my $count = 0;
my $maxReq = 200;

my $uri     = URI::Encode->new( { encode_reserved => 0 } );

my $threads = 50;
my $pm = Parallel::ForkManager->new($threads);
my $dns = Net::DNS::Resolver->new;


#my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=67.80.53.214", 'postgres', undef, {
my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=127.0.0.1", 'postgres', undef, {
      RaiseError => 1,
      InactiveDestroy => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

#my $sth = $dbh->prepare ("select email,name,website,uuid from test_pending_email where sent is null");

my $batch;
## Please see file perltidy.ERR
my $_sth = $dbh->prepare( "select email from mx.pending where resolved is null and random() < 0.1 limit 1000");
 $_sth->execute;
 $batch = $_sth->fetchall_arrayref({});
    print "got " . $#{$batch} . " records\n";
    our $done = 0;

    my $c = 0;
LOOP:
foreach (@$batch) {
  my ($email) = ($uri->decode($_->{email}));
  print "$email\n";
  my $pid = $pm->start and next LOOP;

  try {
  if ($email =~ /\@(.*)$/) {
    my $host = reverse($email);
    $host =~ s/^(.*?)\@.*$/$1/;
    $host = reverse($host);
    my @hosts = mx($dns, $host);
    my $rr = shift @hosts;
    if ( not defined $rr ) {
      my $domain = reverse($email);
      $domain =~ s/^(.*?\..*?)[\.\@].*$/$1/;
      $domain = reverse($domain);
      if ($domain ne $host) {
        @hosts = mx( $dns, $domain );
        $rr = shift @hosts;
      }
    }
    die "no mx for $host" unless( defined $rr );

    my $svr = $rr->exchange();

    my $sth = $dbh->prepare ("insert into mx.mx (email,host) values (?,?) on conflict (email,host) do nothing");
    $sth->execute($email,lc($svr));
    $sth->finish;

     $sth = $dbh->prepare ("update mx.pending set resolved = now() where email = ?");
    $sth->execute($email);
    $sth->finish;
  }
  } catch {
	  print "catch err: $_\n";
  };
  $pm->finish;
}
#} while (($#{$batch} > -1) or ($done != 1));
#$pm->wait_all_children;
sleep 10;

if ($pm->is_parent) {
print "exiting\n";
$dbh->disconnect;
}
