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

# a sub to be run *from within the parent thread* at child creation.
my $init = sub {
  my ($pid, $ident) = @_;
  print "++ $ident started, pid: $pid\n";    
};

# a sub to be run *from within the parent thread* at child termination
my $finalize = sub {
  my ($pid, $exit_code, $ident) = @_;
  print "-- $ident finalized, pid: $pid\n";
};

# set the subrefs
$pm->run_on_start($init); 
$pm->run_on_finish($finalize);

#my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=67.80.53.214", 'postgres', undef, {
my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=winblows98.com", 'postgres', undef, {
      RaiseError => 1,
      InactiveDestroy => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

my $batch;
my $sthp = $dbh->prepare ("select email from mx.pending where resolved is null and random() < 0.1 limit 100");
$sthp->execute;
$batch= $sthp->fetchall_arrayref({});


do {

foreach (@$batch) {
  my ($email) = ($uri->decode($_->{email}));
  my $pid = $pm->start($email) and next;

  try {
  if ($email =~ /\@(.*)$/) {
    my $host = $1;
    my @parts = reverse split(/\./,$1);
    my $domain = sprintf("%s.%s", $parts[1],$parts[0]);

    my @hosts = mx($dns, $host);
    my $rr = shift @hosts;
    if (not defined $rr) {
	    print "error no mx record for $email domain $domain\n";
	    $pm->finish unless( defined $rr );
    }
    my $svr = lc $rr->exchange();
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
    if (not defined $smtp) {
	    print "error: no smtp connection to $svr for $email\n";
	    $pm->finish unless( defined $smtp );
    }
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

    print "resolved $email\n";
    my $sth = $dbh->prepare ("update mx.pending set resolved = now() where email = ?");
    $sth->execute($email);

  } else {
	  print "error: invalid email $email\n"
  }
  } catch {
	  print "catch err: $_\n";
  };
  $pm->finish;
}

	$sthp->execute;
	$batch= $sthp->fetchall_arrayref({});
} while ($#{$batch} > -1);

$pm->wait_all_children;
$dbh->disconnect;
