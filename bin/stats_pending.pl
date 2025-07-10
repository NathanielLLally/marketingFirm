#!/usr/bin/perl
use warnings;
use strict;
use feature 'isa';

use Carp qw/croak longmess/;
use Try::Tiny;
use DBI;
use Data::Dumper;
use Time::HiRes qw(time gettimeofday tv_interval);
use Config::Tiny;
use File::Basename;
use File::Spec;
use Time::Piece;
use AnyEvent;
use Time::Seconds qw/ ONE_DAY /;


my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($dirname, '..','etc','obiseo.conf');
if (not -e $cfgFile) {
	$cfgFile = $ENV{HOME}."/.obiseo.conf";
}
print "using config $cfgFile\n";
our $CFG = Config::Tiny->read( $cfgFile );

my $cv = AnyEvent->condvar;
my $begin =  join '', "$0 ",@ARGV," at ", scalar localtime(), "\n";

my $interval = 10;
my $hist = 12;

my $table = shift @ARGV || 'pending';
my $host = shift @ARGV;

$SIG{HUP} = sub {
  print "process began @\t$begin\n";
  print  "\t\t\t".join '', "$0 @ARGV at ", scalar localtime(), "\n";
};

my $dbh = DBI->connect( $CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},
  { RaiseError => 1, }
) or die "cannot connect: $DBI::errstr";

sub execReconnect
{
  my $sth = shift;
  try {
    $sth->execute();
  } catch {
    if ($_ =~ /no connection to the server/) {
      print "reconnecting to dB\n";
      $dbh = DBI->connect( $CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},
        { RaiseError => 1, }
      ) or die "cannot connect: $DBI::errstr";
    } else {
      print "uncaught error: $_\n";
    }
  };
}

sub getStats {
  #  my $sth = $dbh->prepare("select count(*) as remain, null as requests from pending where resolved is null and url not like '%page=%' union select null as remain, count(*) as requests from pending where resolved is not null and url not like '%page=%'");
 
my $sql;
if (not defined $host) {
$sql = <<EOF
  select count(*) as remain, null as requests from $table
  where resolved is null 
  union
  select null as remain, count(*) as requests from $table
  where resolved is not null
EOF
;
} else {
$sql = <<EOF
  select count(*) as remain, null as requests from $table
  where resolved is null and host = '$host' 
  union
  select null as remain, count(*) as requests from $table
  where resolved is not null and host = '$host'
EOF
;
}
  my $sth = $dbh->prepare($sql);
  execReconnect($sth);
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

my @stats;
push @stats, getStats();
print "interval $interval\n";

  my $w; $w = AnyEvent->timer (
    after => $interval, 
    interval => $interval, 
    cb => sub {
      push @stats, getStats();
      if ($#stats >= $hist) {
        shift @stats;
      }
      my $tdiff = tv_interval($stats[0]->{time}, $stats[-1]->{time});

      my $tMin = 60 / $tdiff;

      my $reqPerT = $stats[-1]->{requests} - $stats[0]->{requests};
      my $reqPerMin = $reqPerT * $tMin;
      print "remaining\t|\trequests\n";
      printf "\t%s\t|\t%s\n\n",$stats[-1]->{remain},$stats[-1]->{requests};
      printf "requests per min %0.1d per hour %0.1d [rolling hist %u]\n", 
        $reqPerMin, $reqPerMin * 60, ($#stats +1);

      if ($reqPerT) {
	      my $r = Time::Seconds->new($stats[-1]->{remain} / $reqPerT * $tdiff);
	      printf "time remainig: %s\n",$r->pretty;
      }
      print "\n";
    }
  );

while ($cv->recv) {
}
  print "exiting\n";
