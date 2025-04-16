#!/usr/bin/perl -w

use strict;
use warnings;

use DBI;
use List::Util qw(shuffle);
use Data::Dumper;
use Config::Tiny;
use File::Basename;
use File::Spec;
use Try::Tiny;
use Carp qw/croak longmess/;

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

use Coro;
use AnyEvent;
use Coro::AnyEvent;
use AnyEvent::HTTP;
#use lib './lib';
#use ParsePURI;
use Time::HiRes qw(time gettimeofday tv_interval);

#  AnyEvent & send_url
my $cv = AnyEvent->condvar;
my $concurrentCount = 0;
my $maxConcurrent = 5;
my @urls;
my $maxUrlCount = 100;


#cfg 
my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($dirname, '..','etc','obiseo.conf');
print "using config $cfgFile\n";
our $CFG = Config::Tiny->read( $cfgFile );

#dbi
my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      InactiveDestroy => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

sub send_url {
  return if $concurrentCount >= $maxConcurrent;
  my $u = shift @urls;
  return if not $u;

  $concurrentCount++;
  $cv->begin;
  print "$u\n";
  http_get $u, timeout => 10, 
  sub { my ($body, $hdr) = @_;
    my $h = HTTP::Headers->new();
    foreach my $k (keys %$hdr) {
      my $v = $hdr->{$k};
      $h->header( $k => $v );
    }
    my $m = HTTP::Message->new($h, $body);
    if ($hdr->{Status} =~ /^2/) {

      try this or www::mechanize
https://metacpan.org/pod/WWW%3A%3AScripter



      my $parser = new HTML::TreeBuilder::Select;
      $parser->parse_content($m->decoded_content()) || croak;

      open(OUT, ">out.html");
      print OUT $h->as_string."\n";
      print OUT $m->decoded_content()."\n";
      close(OUT);
      exit;
    }


    $concurrentCount--;
    $cv->end; 
    send_url();
  };
}



#  MAIN
#  
#######################
my $batch;
my $file = shift @ARGV;
my $FD;
if (defined $file and -e "$file") {
  print "FIX stdin/file in implementation merge with dB inserts ****IFFF IT MATTERS****\n";
  exit;
  open($FD, "<$file") || die "cannot open $file";
  my @batch = <$FD>;
  $batch = \@batch;
  close($FD);
}

my $sth = $dbh->prepare("select domain,dom.id as did from mx_domain dom left join dr_stats dr on dom.id = dr.did where dr.id is null and random () < 0.01 limit 1000");

my @domain;
my $url = "https://data.domainrank.io/compare?";

#build urls with 5 queries per then send it to http_get

my %didByDomain;
my @query;
my $once = undef;

$| = 1; #force flush 
do {
  $sth->execute;
  $batch = $sth->fetchall_arrayref({});
  printf "got %s records\n", $#{$batch} + 1;

  foreach my $row (@$batch) {
    my ($domain, $did) = ($row->{domain}, $row->{did});
    $didByDomain{$domain} = $did;

    push @query, $domain;
    if ($#query == 9) {
      my $query = join("&", map { "domain=$_" } @query);

      if (not defined $once) {
        $once = 1;
        push @urls, "$url$query";
        send_url();
      }
      @query = ();
    }
  }
  while (defined $once or ($#urls > $maxUrlCount)) {    
    Coro::AnyEvent::sleep 1;
    send_url();
  }
} while ($#{$batch} > -1);

$cv->recv;

my $foo = $cv->recv;
print join("\n", @$foo), "\n" if defined $foo;


