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
my $dbhp = DBI->connect("dbi:Pg:dbname=postgres;host=winblows98.com", 'postgres', undef, {
      RaiseError => 1,
    }) or die "cannot connect: $DBI::errstr";

my $batch;
my $sthp = $dbhp->prepare ("select email from mx.pending where resolved is null and random() < 0.1 limit 100");
$sthp->execute;
$batch= $sthp->fetchall_arrayref({});
my $n = 0;
printf "\n\ngot %u records\n\n".$#{$batch};

do {

foreach (@$batch) {
  my ($email) = ($uri->decode($_->{email}));
  my @children = $pm->running_procs;

  printf "%u of %u threads, %u of %u records before start\n",$#children,$pm->max_procs, ++$n, $#{$batch}+1;
  my $pid = $pm->start($email) and next;

  my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=winblows98.com", 'postgres', undef, {
      RaiseError => 1,
    }) or die "cannot connect: $DBI::errstr";

  try {
  if ($email =~ /\@(.*)$/) {
    my $host = $1;
    my @parts = reverse split(/\./,$1);
    my $domain = sprintf("%s.%s", $parts[1],$parts[0]);

    my @hosts = mx($dns, $host);
    my $rr = shift @hosts;
    if (not defined $rr) {
	    my $error =  "no mx record for hostname $host";
	    my $sth = $dbh->prepare ("insert into mx.verified (email,error) values (?,?) on conflict do nothing");
	    $sth->execute($email,$error);
	    $sth = $dbh->prepare ("update mx.pending set resolved = now() where email = ?");
	    $sth->execute($email);
	    print "error for email $email: $error\n";
	    $dbh->disconnect;
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
	    my $error =  "could not connect to smtp server $svr";
	     print "error for email $email: $error\n";

	    my $sth = $dbh->prepare ("insert into mx.verified (email,error) values (?,?) on conflict do nothing");
	    $sth->execute($email,$error);
	    $sth = $dbh->prepare ("update mx.pending set resolved = now() where email = ?");
	    $sth->execute($email);
	    $dbh->disconnect;
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
  $dbh->disconnect;
  $pm->finish;
}
	print "end of loop\n";
if ($pm->is_parent) {
	print "getting new batch\n";
my $dbhp = DBI->connect("dbi:Pg:dbname=postgres;host=winblows98.com", 'postgres', undef, {
      RaiseError => 1,
    }) or die "cannot connect: $DBI::errstr";
	my $sthp = $dbhp->prepare ("select email from mx.pending where resolved is null and random() < 0.1 limit 100");
	$sthp->execute;
	$batch= $sthp->fetchall_arrayref({});
	printf "\n\ngot %u records\n\n",$#{$batch};
} else {
	print "why is child reaching here?\n";
}
} while ($#{$batch} > -1 and $pm->is_parent);

if ($pm->is_parent) {
	print "exited, waiting\n";
	$pm->wait_all_children;
	$dbhp->disconnect;
}
