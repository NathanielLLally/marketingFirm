#!/usr/bin/perl
use warnings;
use strict;
use Modern::Perl;
use feature 'isa';
use Try::Tiny;
use DBI;
use DBD::CSV;
use LWP;
#use LWP::Debug qw(+);
use Data::Dumper;

use HTTP::Request;
use HTML::Parser ();
use HTML::Tagset ();
use HTML::Element;
use HTML::TreeBuilder;
use HTML::TreeBuilder::Select;
use HTTP::Request::Common ();
use HTTP::Request;
use HTTP::Response;
use HTTP::Cookies;
use HTTP::Message;
use HTTP::Headers;
use Carp qw/croak longmess/;
use Try::Tiny;
use DBI;
use DBD::CSV;
use Data::Dumper;
use Coro;
use AnyEvent;
use Coro::AnyEvent;
use AnyEvent::HTTP;
use PURI;
use Time::HiRes qw(time gettimeofday tv_interval);
use Config::Tiny;
use File::Basename;
use File::Spec;
use Time::Piece;
use Time::Seconds qw/ ONE_DAY /;


my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($dirname, '..','etc','obiseo.conf');
print "using config $cfgFile\n";
our $CFG = Config::Tiny->read( $cfgFile );

my $cv = AnyEvent->condvar;
my $begin =  join '', "$0 ",@ARGV," at ", scalar localtime(), "\n";
my $interval = 10;

$SIG{HUP} = sub {
  print "process began @\t$begin\n";
  print  "\t\t\t".join '', "$0 @ARGV at ", scalar localtime(), "\n";
};

my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

sub getStats {
  #  my $sth = $dbh->prepare("select count(*) as remain, null as requests from pending where resolved is null and url not like '%page=%' union select null as remain, count(*) as requests from pending where resolved is not null and url not like '%page=%'");
  my $sth = $dbh->prepare("select count(*) as remain, null as requests from pending where resolved is null union select null as remain, count(*) as requests from pending where resolved is not null");
  $sth->execute();
  my $rs = $sth->fetchall_arrayref({});

  my $stats = {
    time => [gettimeofday]
  };
  foreach my $row (@$rs) {
    if (defined $row->{remain} and length($row->{remain}) > 0) {
      $stats->{remain} = $row->{remain};
    }
    if (defined $row->{requests} and length($row->{requests}) > 0) {
      $stats->{requests} = $row->{requests};
    }
  }
  return $stats;
}

my $stats = getStats();
print Dumper(\$stats);

  my $w; $w = AnyEvent->timer (
    after => $interval, 
    interval => $interval, 
    cb => sub {
      my $cstat = getStats();
      my $tdiff = tv_interval($stats->{time}, $cstat->{time});

      my $tMin = 60 / $tdiff;

      my $reqPerT = $cstat->{requests} - $stats->{requests};
      my $reqPerMin = $reqPerT * $tMin;
      print "remaining\t|\trequests\n";
      printf "\t%s\t|\t%s\n",$cstat->{remain},$cstat->{requests};
      printf "requests per min %0.1d\n", $reqPerMin;

      my $r = Time::Seconds->new($cstat->{remain} / $reqPerT * $tdiff);
      printf "time remainig: %s\n",$r->pretty;
    }
  );

while ($cv->recv) {
}
  print "exiting\n";
