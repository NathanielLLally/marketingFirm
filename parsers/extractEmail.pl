#!/usr/bin/perl
use warnings;
use strict;
use Modern::Perl;
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
use AnyEvent::UserAgent;
use PURI;
use Time::HiRes qw(time gettimeofday tv_interval);

my $ua = AnyEvent::UserAgent->new;

my $cv = AnyEvent->condvar;
my $count = 0;

my $disperseTime = 1;
my $fqcount = {};
my $maxSameDomain = 5;
my $maxReqs = 100;
my $maxQueue = 101;

my %seen;
my %disperse;
my @urls;
my $begin =  join '', "$0 ",@ARGV," at ", scalar localtime(), "\n";

$SIG{HUP} = sub {
  print "process began @\t$begin\n";
  print  "\t\t\t".join '', "$0 @ARGV at ", scalar localtime(), "\n";
};

my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=127.0.0.1", 'postgres', undef, {
      RaiseError => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";


sub on_return {

  no warnings;
  our $parser = new HTML::TreeBuilder::Select; 
  my ($website, $res) = @_;
  my $h = PURI::parse($website);
  my @ke = keys %$h;
  my $origin = $h->{$ke[0]}->{fqdn};

  print "returned $website\n";

  my $m = HTTP::Message->new($h, $body);
  if ($res->is_success) {
    #
    $parser->parse_content($res->decoded_content()) || croak;
    #$parser->parse_content($body) || croak;
    my @a = $parser->look_down(_tag => 'a');
    foreach my $el (@a) {
      #print $el->tag."\n";
      if ($el->attr('href') =~ /^((mailto:)?\s?(.*?\@.*?\.\w+))/) {
        my $email ="$3";
        if ($el->attr('href') !~ /^https?:\/\//) {
        print "wholly email batman, [$email]\n";
          #mailto: might be responsible for breaking crm import


          #          print Dumper($res->headers);
          #print Dumper(\$array);
          try {
            my $sth = $dbh->prepare ("INSERT into email (email,website, hdrurl) values (?,?,?) on conflict(email,website) do nothing");
            $sth->execute ($email, $website, $res->header('URL'));
            $sth->finish;
          } catch {
          };
        }
      }
    }


    foreach my $el (@a) {
      my $url = lc($el->attr('href'));
      my $h = PURI::parse($url);
      my @ke = keys %$h;
      my $fqdn = $h->{$ke[0]}->{fqdn};

      if (
        ($fqdn eq $origin) &&
        ($url =~ /^https?/) &&
        ($h->{$ke[0]}->{path} =~ /(about|contact|facebook)/)
      ) {
        if ($fqcount->{$fqdn} <= $maxSameDomain) {
          push @urls, $url;
          send_url();
        }
      } 
    }
  } elsif ($res->code == '404') {
    my $sth = $dbh->prepare ("update pending set resolved = now(),status = ? where url = ?");
    $sth->execute($res->code, $website);
    $sth->finish;
  }

  my $sth = $dbh->prepare ("update pending set resolved = now() where url = ?");
  $sth->execute($website);
  $sth->finish;
  use warnings;
  return;
}


#        # Simple statements
#        $dbh->do ("CREATE TABLE foo (id INTEGER, name CHAR (10))");
#
# make csv for importing into postgres
# also must use iconv to convert to UTF8
my $sth = $dbh->prepare ("select url from pending where resolved is null");


my $result;


sub send_url {
  return if $count >= $maxReqs;
  my $u = shift @urls;
  return if not $u;
  return if (exists $seen{$u});

  #  dont hit individual domains more than x per y (1 per 10 as of now)
  my $h = PURI::parse($u);
  my @ke = keys %$h;
  my $fqdn = $h->{$ke[0]}->{fqdn};
  if (not exists $fqcount->{$fqdn}){
    $fqcount->{$fqdn} = 0;
  } else {
    $fqcount->{$fqdn}++;
  }
  if (not exists $disperse{$fqdn} or tv_interval($disperse{$fqdn}, [gettimeofday]) > $disperseTime) {
    #    $disperse{$fqdn} = [gettimeofday];
    $count++;
    $cv->begin;
    $seen{$u} = 1;
    print ".";
    my $url = $u;
    $ua->get( $url, timeout => 10, 
      sub { my ($res) = @_; $count--; on_return($url,$res); $cv->end; send_url() });
  } else {
    push @urls, $u;
    send_url();
  }
}

$| = 1;
while ($sth->execute) {
  
  my $batch = $sth->fetchall_arrayref({});
  foreach (@$batch) {

    push @urls, $_->{url};
    send_url();

  }
  while ($#urls > $maxQueue) {    
    Coro::AnyEvent::sleep 1;
    send_url();
  }
  print "\n**  BATCH ***********************************\n";
};
$cv->recv;
#EV: error in callback (ignoring): Wide character in syswrite at /usr/lib64/perl5/vendor_perl/AnyEvent/Handle.pm line 2291.


my $foo = $cv->recv;
print join("\n", @$foo), "\n" if defined $foo;

