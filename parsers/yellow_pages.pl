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
my $ua = AnyEvent::UserAgent->new;

my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($ENV{HOME}, '.yellow_pages.conf');
if (not -e $cfgFile) {
  # fallback to older name for backward compatibility
  $cfgFile = File::Spec->catfile($ENV{HOME}, '.obiseo.conf');
}
print "using config $cfgFile\n";
our $CFG = Config::Tiny->read( $cfgFile );
die "cannot read config from $cfgFile: $!" if not defined $CFG;
if (not defined $CFG->{dB}) {
  die "config missing [dB] section (dsn, user, pass required)";
}

my $cv = AnyEvent->condvar;
my $count = 0;

#
# Crawler fleet: the hostnames pending_yp rows are sharded across. A worker
# only ever claims rows whose host matches its own Sys::Hostname::hostname(),
# so a box missing from this list gets zero work and exits immediately.
#
# Override in the config to match your actual fleet:
#
#   [crawler]
#   hosts = mail.htcp.com,mail.obiseo.net
#
# With no [crawler] section we shard to this host alone, which is the only
# safe default: it guarantees the local worker can claim what it queues.
#
my @fleet = ($host);
if (defined $CFG->{crawler} and defined $CFG->{crawler}->{hosts}) {
  @fleet = grep { length } map { s/^\s+|\s+$//gr } split /,/, $CFG->{crawler}->{hosts};
  die "config [crawler] hosts is empty" if not @fleet;
}
print "sharding queue across: " . join(", ", @fleet) . "\n";

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
      } else {
        # Record every non-success status, not just 404. Previously anything
        # else (403 bot-block, 5xx, timeout) was printed and left unresolved,
        # so the worker retried it forever and the queue never drained.
        print $res->status_line . "\n";
        try {
          my $sth = $dbh->prepare ( "update yellow_pages.pending_yp set resolved = now(), status = ? where url = ?");
          $sth->execute ( $res->code, $url );
          $sth->finish;
        } catch {
          warn "Error recording status " . $res->code . " for $url: $_\n";
        };
      }

      $count--;
      $cv->end; 
      send_url() 
    });
  }
}

#
# Clear pending_yp and refill it from yellow_pages_citycat, assigning each
# row a random host from @fleet. Returns the number of rows queued.
#
sub rebuild_queue {
  my $sth = $dbh->prepare("delete from yellow_pages.pending_yp");
  $sth->execute();

  # random() is volatile, so the subscript is re-evaluated per output row.
  # (A LATERAL subquery here would be uncorrelated and assign every row the
  # same host - verified against PostgreSQL, don't "simplify" it back.)
  $sth = $dbh->prepare("insert into yellow_pages.pending_yp (url,host)
    -- the www host is required: https://yellowpages.com/... 301-redirects to
    -- the homepage, which the worker then parses as an empty listing page and
    -- marks resolved/200 without extracting anything.
    select concat('https://www.yellowpages.com', c.url) as url,
           (?::text[])[1 + floor(random() * array_length(?::text[], 1))::int] as host
      from yellow_pages.yellow_pages_citycat c
    on conflict do nothing");
  $sth->execute(\@fleet, \@fleet);

  my $rows = $sth->rows;
  $sth->finish;
  return $rows;
}

$| = 1;

if (defined $Pcat and $Pcat eq "pending") {
  my $queued = rebuild_queue();
  print "Queued $queued city-category URLs for crawling.\n";
  if ($queued == 0) {
    print STDERR "yellow_pages.yellow_pages_citycat is empty - run bootstrap first:\n";
    print STDERR "  $0 bootstrap\n";
    exit 1;
  }
  exit 0;

} elsif (defined $Pcat) {
  # Bootstrap mode: discover categories and city-category combinations
  # Fetch categories from /categories, then per-city URLs from /categories/<category>
  # Queue the results in pending_yp and exit.

  print "=== Bootstrap mode: discovering categories and city-category combinations ===\n";

  # A condvar is single-use: once it fires, every later recv() returns
  # immediately. Step 2 therefore needs its own, or it returns before any
  # HTTP callback has run and the inserts never happen.
  $cv = AnyEvent->condvar;
  $cv->begin;

  my $url = "https://www.yellowpages.com/categories";
  print "Step 1: Fetching main categories from $url\n";
  push @urls, {url => $url, cb => sub {
      my ($url, $parser) = @_;
      my @a = $parser->look_down(_tag => 'a');
      my $count = 0;
      foreach my $el (@a) {
        # anchors without href (named targets, JS handlers) are common here
        if (defined $el->attr('href') and $el->attr('href') =~ /categories\/([\w\-]+)/) {
          try {
            my $cat = $1;
            my $sth = $dbh->prepare ("INSERT into yellow_pages.yellow_pages_categories (category) values (?) on conflict(category) do nothing");
            $sth->execute ($cat);
            $sth->finish;
            $count++;
            print ".";
          } catch {
            warn "Error inserting category $1: $_\n";
          };

        }
      }
      print "\nInserted $count categories\n";
    }};
  send_url();

  $cv->end;

  # Wait for categories to be fetched and inserted
  $cv->recv;

  print "\nStep 2: Fetching per-city URLs for each category\n";

  my $sth = $dbh->prepare ("select category from yellow_pages.yellow_pages_categories order by category");
  $sth->execute();
  my $rs = $sth->fetchall_arrayref({});

  if ($#{$rs} < 0) {
    print STDERR "No categories found in database. Bootstrap failed.\n";
    exit 1;
  }

  printf "Found %d categories, discovering city URLs...\n", $#{$rs} + 1;

  # fresh condvar: the Step 1 one has already fired (see above)
  $cv = AnyEvent->condvar;
  $cv->begin;
  my $catCount = 0;
  foreach my $row (@$rs) {
    my $category = $row->{category};
    my $catUrl = sprintf("https://www.yellowpages.com/categories/%s", $category);
    push @urls, {url => $catUrl, cb => sub {
        my ($url, $parser) = @_;
        my @a = $parser->look_down(_tag => 'a');
        my $cityCount = 0;
        foreach my $el (@a) {
          if (defined $el->attr('href') and $el->attr('href') =~ /$category/) {
            try {
              my $cityUrl = $el->attr('href');
              my $sth = $dbh->prepare ("INSERT into yellow_pages.yellow_pages_citycat (url) values (?) on conflict(url) do nothing");
              $sth->execute ($cityUrl);
              $sth->finish;
              $cityCount++;
            } catch {
              warn "Error inserting citycat URL for $category: $_\n";
            };
          }
        }
        print "." if $cityCount > 0;
      }};
    send_url();
    $catCount++;
  }

  $cv->end;

  # Wait for all city URLs to be fetched and inserted
  print "\nWaiting for all city-category URLs to be fetched...\n";
  $cv->recv;

  print "\nStep 3: Building crawl queue from discovered URLs\n";

  my $rowsInserted = rebuild_queue();
  print "Queued $rowsInserted city-category URLs for crawling.\n";

  if ($rowsInserted == 0) {
    print STDERR "\nNo city-category URLs were discovered - nothing to crawl.\n";
    print STDERR "yellowpages.com's markup may have changed; check the link scraping above.\n";
    exit 1;
  }

  print "\n=== Bootstrap complete ===\n";
  print "Run with 'pending' argument to rebuild queue, or no argument to start workers.\n";

  exit 0;
}

# the worker reuses $cv below; make sure it is a fresh one
$cv = AnyEvent->condvar;


#my $sth = $dbh->prepare ("select url from yellow_pages.pending_yp where resolved is null and url not like '%page=%' and random() < 0.01 limit 1");

#my $sth = $dbh->prepare ("select url from yellow_pages.pending_yp where resolved is null and host = ? and random() < 0.01 limit 10");
my $sth = $dbh->prepare ("select url from yellow_pages.pending_yp where resolved is null and host = ?");

$sth->execute($host);
my $rs = $sth->fetchall_arrayref({});

#
# No work for this host is almost always a misconfiguration rather than a
# finished crawl, so say which of the two it is instead of exiting silently.
#
if ($#{$rs} < 0) {
  my $tot = $dbh->selectrow_array("select count(*) from yellow_pages.pending_yp");
  print STDERR "No unresolved URLs for host '$host'.\n";
  if ($tot == 0) {
    print STDERR "The queue is empty. Run:  $0 bootstrap   then:  $0 pending\n";
  } else {
    my $hosts = $dbh->selectcol_arrayref(
      "select distinct coalesce(host,'(null)') from yellow_pages.pending_yp order by 1");
    print STDERR "Queue holds $tot rows, sharded to: " . join(", ", @$hosts) . "\n";
    print STDERR "This host is not among them. Add it to [crawler] hosts and re-run '$0 pending'.\n";
  }
  exit 1;
}

$cv->begin;

my ($pageTotalN, $pageN, $pageTotal, $DEBUG) = (0,30, 0, 1); 
do {
  print "got ".$#{$rs}."\n";
  foreach my $row (@$rs) {
    my $url = $row->{url};
    push @urls, {
      url => $url,
      cb => sub {
        my ($url, $parser) = @_;

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
                my $sth = $dbh->prepare ("INSERT into yellow_pages.pending_yp (url,host) values (?,?) on conflict do nothing");
                $sth->execute (sprintf("%s?page=%s",$newurl,$n),$host);
                $sth->finish;
              } catch {
                warn "Error queueing pagination URL for page $n: $_\n";
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
              sprintf("INSERT into yellow_pages.yellow_pages_loading (%s) values (%s)",
                join(",",@keys), join(",", @q))
            );

            $sth->execute (@vals);
            $sth->finish;
          } catch {
            warn "Error inserting business listing for " . ($nfo->{name} // 'unknown') . ": $_\n";
          };
        }

        #
        #  done parsing, update crawler pending
        #
        try {
          my $sth = $dbh->prepare ( "update yellow_pages.pending_yp set resolved = now(), status = 200 where url = ?");
          $sth->execute ($url);
          $sth->finish;
        } catch {
          warn "Error marking $url as resolved: $_\n";
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
} while ($#{$rs} > -1);
#} while (1 eq 1);
$cv->end;

$cv->recv;


print "recv happened\n";
