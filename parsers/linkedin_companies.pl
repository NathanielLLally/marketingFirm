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
use AnyEvent::UserAgent;
use PURI;
use Time::HiRes qw(time gettimeofday tv_interval);
use Config::Tiny;
use File::Basename;
use File::Spec;
use Sys::Hostname;

my $host = hostname();
my $ua = AnyEvent::UserAgent->new({agent=>"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"});

my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($ENV{HOME}, '.obiseo.conf');
print "using config $cfgFile\n";
our $CFG = Config::Tiny->read( $cfgFile );

my $cvSesh = AnyEvent->condvar;
my $Gcv = AnyEvent->condvar;
my $count = 0;

my $disperseTime = 1;
my $fqcount = {};
my $maxSameDomain = 10;
my $maxReqs = 10;
my $maxQueue = 10;

my %seen;
my %disperse;
my @urls;
my $begin =  join '', "$0 ",@ARGV," at ", scalar localtime(), "\n";


my $Pcat = shift @ARGV;

$SIG{HUP} = sub {
  print "process began @\t$begin\n";
  print  "\t\t\t".join '', "$0 @ARGV at ", scalar localtime(), "\n";
};

my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

sub send_url {
  my $cv = shift || $Gcv; 
  return if $count >= $maxReqs;
  my $u = shift @urls;
  return if not defined $u and ref($u) ne 'HASH';

  $count++;
  $cv->begin;
  {
    my $url = $u->{url};
    my $cb = $u->{cb};
    print "http_get $url\n";
    $ua->get( $url, timeout => 10, 
    sub { 
      my ($res) = @_;
      print "returned $url ";

      if ($res->is_success) {
        print "parsing\n";
        my $parser = new HTML::TreeBuilder::Select; 
        $parser->parse_content($res->decoded_content()) || croak;
        $cb->($url,$parser);
      } elsif ($res->code == 404) {
        print "not found\n";
        try {
          my $sth = $dbh->prepare ( "update pending_li set resolved = now(), status = ? where url = ?");
          $sth->execute ( $res->code, $url );
          $sth->finish;
        } catch {
          print "update error: $_\n";
        };
      } else {
        print "\n\t \__>". $res->status_line."\n";
        print "\n\t \__>". $res->code."rn";
      }

      $count--;
      $cv->end; 
      send_url() 
    });
  }
}

$| = 1;

if (defined $Pcat and $Pcat eq "pending") {
  my $sth = $dbh->prepare("delete from pending_li");
  $sth->execute();
  $sth = $dbh->prepare("insert into pending_li (url,host)
    select concat('https://yellowpages.com',url) as url, 
    ('[0:3]={mail.obiseo.net,mail.accurateleadinfo.com,mail.leadtinfo.com,mail.winblows98.com}'::text[])[floor(random()*4)]
    as host
    from tycat
    ");
  $sth->execute();

} elsif (defined $Pcat) {

  #  $cv->begin;

  print "fetching cookies.. session key?\n";
  my $url = "https://www.linkedin.com";
  push @urls, {url => $url, cb => sub {
      my ($url, $parser) = @_;
      print "in callback\n";
      print(Dumper($ua->cookie_jar));
    }};
  send_url($cvSesh);

  $cvSesh->recv;

  #  $cv->begin;
  $url = "https://www.linkedin.com/directory/companies?trk=homepage-basic_directory_companyDirectoryUrl";
  print "fetching companies\n";
  push @urls, {url => $url, cb => sub {
      my ($url, $parser) = @_;
      my @a = $parser->look_down(_tag => 'a');
      foreach my $el (@a) {
        if ($el->attr('href') =~ /(.*?)/) {
          try {
            print "$1\n";
          } catch {
          };

        }
      }
      print "fetched\n";
    }};
  send_url();

  #  $cv->end;

}

print "main loop\n";
$Gcv->recv;
print "post recv\n";
