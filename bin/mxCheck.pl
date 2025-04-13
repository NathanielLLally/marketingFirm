#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Email::Sender::Simple qw(sendmail try_to_sendmail);
use Email::Sender::Transport::SMTPS;
use Email::Simple ();
use Email::Simple::Creator ();
use Email::MIME;
use Parallel::ForkManager;
use DBI;
use Data::Dumper;
use URI::Encode;

my $pm = Parallel::ForkManager->new(30);

my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=127.0.0.1", 'postgres', undef, {
      RaiseError => 1,
      InactiveDestroy => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

  my $sth = $dbh->prepare ("select email from email");
  #my $sth = $dbh->prepare ("select email,name,website,uuid from test_pending_email where sent is null");
my $batch;
my %seen;

open(OUT, ">domains");

  $sth->execute;
  $batch = $sth->fetchall_arrayref({});

my $uri     = URI::Encode->new( { encode_reserved => 0 } );

  foreach (@$batch) {
    my ($email, $uuid, $name, $website) = ($_->{email}, $_->{uuid}, $_->{name}, $_->{website});
    if ($email =~ /\@(.*)/) {
        my $domain = $uri->decode($1);
        print OUT "$1\n";
    }

  }


  #iconv -f UTF-8 -t ASCII//TRANSLIT

$dbh->disconnect;
close OUT;
