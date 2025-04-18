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


my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($dirname, '..','etc','obiseo.conf');
print "using config $cfgFile\n";
our $CFG = Config::Tiny->read( $cfgFile );

my $cv = AnyEvent->condvar;
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

$SIG{HUP} = sub {
  print "process began @\t$begin\n";
  print  "\t\t\t".join '', "$0 @ARGV at ", scalar localtime(), "\n";
};

my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

sub send_url {
  return if $count >= $maxReqs;
  my $u = shift @urls;
  return if not defined $u and ref($u) ne 'HASH';

  $count++;
  $cv->begin;
  {
    my $url = $u->{url};
    my $cb = $u->{cb};
    print "http_get $url\n";
    http_get $url, timeout => 10, 
    sub { 
      my ($body, $hdr) = @_;
      print "returned $url ";

      my $h = HTTP::Headers->new();
      foreach my $k (keys %$hdr) {
        my $v = $hdr->{$k};
        $h->header( $k => $v );
      }
      my $m = HTTP::Message->new($h, $body);
      if ($hdr->{Status} =~ /^2/) {
        print "parsing\n";
        my $parser = new HTML::TreeBuilder::Select; 
        $parser->parse_content($m->decoded_content()) || croak;
        $cb->($url,$hdr,$parser);
      } elsif ($hdr->{Status} == 404) {
        print "not found\n";
        try {
          my $sth = $dbh->prepare ( "update pending set resolved = now(), status = ? where url = ?");
          $sth->execute ( $hdr->{Status}, $url );
          $sth->finish;
        } catch {
          print "update error: $_\n";
        };

      } else {
        print Dumper($hdr);
      }

      $count--;
      $cv->end; 
      send_url() 
    };
  }
}

$| = 1;

=head2 fetch categories and cities

$cv->begin;

my $url = "https://www.yellowpages.com/categories";
print "fetching categories\n";
    push @urls, {url => $url, cb => sub {
        my ($url, $hdr, $parser) = @_;
        my @a = $parser->look_down(_tag => 'a');
        foreach my $el (@a) {
          if ($el->attr('href') =~ /categories\/([\w\-]+)/) {
            try {
              print ".";
              my $sth = $dbh->prepare ("INSERT into yellow_pages_categories (category) values (?) on conflict(category) do nothing");

              $sth->execute ($1);
              $sth->finish;
            } catch {
            };

          }
        }
        print "fetched\n";
      }};
    send_url();

$cv->end;


print "\nfetching category cities\n";

my $sth = $dbh->prepare ("select category from yellow_pages_categories");
$sth->execute();
my $rs = $sth->fetchall_arrayref({});

$cv->begin;
foreach my $row (@$rs) {
    push @urls, {url => sprintf("%s%s",
        "https://www.yellowpages.com/categories/",
        $row->{category}),
        cb => sub {
        my ($url, $hdr, $parser) = @_;
        my @a = $parser->look_down(_tag => 'a');
        foreach my $el (@a) {
          my $cat = $row->{category};
          if ($el->attr('href') =~ /$cat/) {
            try {
              print ".";
              my $sth = $dbh->prepare ("INSERT into yellow_pages_citycat (url) values (?) on conflict(url) do nothing");

              $sth->execute ($el->attr('href'));
              $sth->finish;
            } catch {
            };

          }
        }
        print "\n";
      }};
  send_url();
}

$cv->end;
print "fetched\n";
=cut

#my $sth = $dbh->prepare ("select url from pending where resolved is null and url not like '%page=%' and random() < 0.01 limit 1");

my $sth = $dbh->prepare ("select url from pending where resolved is null and random() < 0.01 limit 10");

$sth->execute();
my $rs = $sth->fetchall_arrayref({});

$cv->begin;

my ($pageTotalN, $pageN, $pageTotal, $DEBUG) = (0,30, 0, 1); 
do {
  print "got ".$#{$rs}."\n";
  foreach my $row (@$rs) {
    my $url = $row->{url};
    push @urls, {
      url => $url,
      cb => sub {
        my ($url, $hdr, $parser) = @_;

        #
        #  look for page count, insert generated links into pending
        #
        my @span = $parser->look_down(_tag => 'span', class=>'showing-count');
        foreach my $el (@span) {
          if ($el->as_text =~ /Showing 1\-(\d+) of (\d+)/) {
            $pageN = $1;
            $pageTotalN = $2;
            my $newurl = $url;
            $newurl =~ s/\?.*//;
            $pageTotal = int($pageTotalN / $pageN)+1;
            foreach my $n (2..$pageTotal) {
              try {
                my $sth = $dbh->prepare ("INSERT into pending (url) values (?) on conflict do nothing");
                $sth->execute (sprintf("%s?page=%s",$newurl,$n));
                $sth->finish;
              } catch {
              };
            }
          }
        }
        #
        #  parse info about each business and insert
        #
        my @div = $parser->look_down(_tag => 'div', class=>'info');
        foreach my $el (@div) {
          my $css = 'business-name';
          my @tags = $el->look_down(class => $css);
          my $tag;
          my $nfo = {};
          if ($url =~ /.*\/([\w\-]+)/) {
            $nfo->{category} = $1;
          }

          $nfo->{name} = $tags[0]->as_text;

          $css = 'track-visit-website';
          @tags = $el->look_down(class => $css);
          $tag = shift @tags;
          $nfo->{website} = (defined $tag) ? $tag->attr('href') : "";

          $css = 'bbb-rating';
          @tags = $el->look_down(class => $css);
          $tag = shift @tags;
          $nfo->{tags} = (defined $tag) ? "BBB-Accredited" : "";

          #    my $info = $parser->parse($el);
          #my @el = $info->select("div[class*=phone]");
          #foreach my $i (@el) {
          #    print $i->as_text."\n";
          #}

          #TODO
          #    my @css = ('phone', 'phones phone primary', 
          $css = 'phone';
          @tags = $el->look_down(class => $css);
          $tag = shift @tags;
          if (defined $tag) {
            $nfo->{phone} = $tag->as_text;
          } else {
            $css = 'phones phone primary';
            @tags = $el->look_down(class => $css);
            $tag = shift @tags;
            $nfo->{phone} = (defined $tag) ? $tag->as_text : "";
          }

          #TODO performance
          $css = 'street-address';
          @tags = $el->look_down(class => $css);
          $tag = shift @tags;

          $css = 'adr';
          @tags = $el->look_down(class => $css);
          my $elsetag = shift @tags;
          $nfo->{address} = (defined $tag) ? $tag->as_text : ((defined $elsetag) ? $elsetag->as_text : "123 Anystreet, HV");

          $css = 'locality';
          @tags = $el->look_down(class => $css);
          $tag = shift @tags;
          #$nfo->{$css} = (defined $tag) ? $tag->as_text : "";
          if (defined $tag) {
            $tag = $tag->as_text;

            if ($tag =~ /(.*?)\,.?(\w\w).?(\d+)/ ) {
              ($nfo->{city}, $nfo->{state}, $nfo->{zip}) = ($1, $2, $3);
            }
          }

          try {
            print ".";
            my @keys = sort keys %$nfo;
            my @q = map { '?' } @keys;
            my @vals = map { $nfo->{$_} } @keys;

            my $sth = $dbh->prepare (
              sprintf("INSERT into yellow_pages (%s) values (%s)",
                join(",",@keys), join(",", @q))
            );

            $sth->execute (@vals);
            $sth->finish;
          } catch {
          };
        }

        #
        #  done parsing, update crawler pending
        #
        try {
          my $sth = $dbh->prepare ( "update pending set resolved = now(), status = 200 where url = ?");
          $sth->execute ($url);
          $sth->finish;
        } catch {
        };

      }};
    send_url();
  }
  while ($#urls > $maxQueue) {    
    Coro::AnyEvent::sleep 1;
    send_url();
  }

  $sth->execute();
  $rs = $sth->fetchall_arrayref({});
} while (1 eq 1);
#while ($#{$rs} > -1);
$cv->end;

$cv->recv;


print "recv happened\n";
