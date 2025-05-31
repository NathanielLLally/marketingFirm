#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Net::SMTP;
use DBI;
use Data::Dumper;
use Net::DNS::Async;
use URI::Encode;
use Net::SMTP;
use Data::Dumper;
use Coro::AnyEvent;
use Parallel::ForkManager;
use Net::DNS;
use Try::Tiny;
use Sys::Hostname;

my $count = 0;
my $maxReq = 200;

my $uri     = URI::Encode->new( { encode_reserved => 0 } );

my $threads = 30;
my $pm = Parallel::ForkManager->new($threads);
my $dns = Net::DNS::Resolver->new;


#my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=67.80.53.214", 'postgres', undef, {
my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=127.0.0.1", 'postgres', undef, {
      RaiseError => 1,
      InactiveDestroy => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

my $sth = $dbh->prepare ("select email from mx.pending where resolved is null and random() < 0.1 limit 100");
#my $sth = $dbh->prepare ("select email,name,website,uuid from test_pending_email where sent is null");

$sth->execute;
my $batch = $sth->fetchall_arrayref({});

LOOP:
foreach (@$batch) {
  my ($email) = ($uri->decode($_->{email}));
  print "$email\n";
  my $pid = $pm->start and next LOOP;

  try {
  if ($email =~ /\@(.*)$/) {
    my @parts = reverse split(/\./,$1);
    my $domain = sprintf("%s.%s", $parts[1],$parts[0]);

    my @hosts = mx($dns, $domain);
    my $rr = shift @hosts;
    $pm->finish unless( defined $rr );
    my $svr = $rr->exchange();
    my $smtp = Net::SMTP->new($svr,
	    Timeout => 30,
	    Hello => hostname,
	    #Debug   => 1,
    );

    #$smtp->verify($email);
    #	my $vrfyCode = $smtp->code;
    #	if ($vrfyCode != 252) {
    #	}

    #rule out false positives
    $pm->finish unless( defined $smtp );
    $smtp->mail($email);
    if ($smtp->to("adln12jqewfkjbrwgsdjh\@$domain")) {
	    my $sth = $dbh->prepare ("insert into mx.verified (email,error) values (?,?) on conflict do nothing");
	    $sth->execute($email,sprintf("false positive check failed for mx %s", $svr));
	    $sth->finish;
    } else {
	    $smtp->reset;
	    $smtp->mail($email);
	    if ($smtp->to($email)) {
		    my $sth = $dbh->prepare ("insert into mx.verified (email) values (?) on conflict do nothing");
		    $sth->execute($email);
		    $sth->finish;
		    #sahksess
		    #
	    } else {
		    print "Error: ", $smtp->message();
		    my $sth = $dbh->prepare ("insert into mx.verified (email,error) values (?,?) on conflict do nothing");
		    $sth->execute($email,join(' ',$smtp->message()));
		    $sth->finish;
	    }
    }
    $smtp->quit;

    my $sth = $dbh->prepare ("update mx.pending set resolved = now() where email = ?");
    $sth->execute($email);
    $sth->finish;
  }
  } catch {
	  print "catch err: $_\n";
  };
  $pm->finish;
}
sleep 20;
$dbh->disconnect;
