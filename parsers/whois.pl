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

use Carp qw/croak longmess/;
use Try::Tiny;
use DBI;
use Data::Dumper;
use Coro;
use AnyEvent;
use Coro::AnyEvent;
use AnyEvent::Whois::Raw;
use PURI;
use Time::HiRes qw(time gettimeofday tv_interval);
use Config::Tiny;
use File::Basename;
use File::Spec;


my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($dirname, '..','etc','obiseo.conf');
print "using config $cfgFile\n";
our $CFG = Config::Tiny->read( $cfgFile );

my $DEBUG = 0;

my $cv = AnyEvent->condvar;
my $count = 0;

my $disperseTime = 1;
my $fqcount = {};
my $maxSameDomain = 10;
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
    print "whois $url\n";
    whois $url, timeout => 10, 
    sub {
      print "returned $url\n";
      my $data = shift;
      if ($data) {
        my $srv = shift;
        $cb->($data,$srv,$url);
      }
      elsif (! defined $data) {
        my $srv = shift;
        print "no information for domain on $srv found";
      }
      else {
        my $reason = shift;
        print "whois error: $reason";
      }

      $count--;
      $cv->end; 
      send_url() 
    };
  }
}

$| = 1;

=head2 example 

Registrant Name: Internet Domain Admin
Registrant Organization: Primerica Life Insurance Company
Registrant Street: 1 PRIMERICA PARKWAY
Registrant City: Duluth
Registrant State/Province: GA
Registrant Postal Code: 30099-0001
Registrant Country: US
Registrant Phone: +1.7703811000
Registrant Phone Ext: 
Registrant Fax: +1.7703811000
Registrant Fax Ext: 
Registrant Email: domain.admin@primerica.com

=cut

print "\nfetching whois\n";


my $dbField = {
  Name => 'name',
  Organization => 'organization',
  Street => 'street',
  City => 'city',
  'State/Province' => 'state',
  Country => 'country',
  Phone => 'phone',
  'Phone Ext' => 'phone_ext',
  'Postal Code' => 'zip',
  'Fax' => 'fax',
  'Fax Ext' => 'fax_ext',
  Email => 'email'
};
my @f = map { $_ } sort values %$dbField;
my @q = map { '?' } values %$dbField;


my $sth = $dbh->prepare ("select domain from pending_whois where resolved is null and random() < 0.01 limit 10");
$sth->execute();
my $rs = $sth->fetchall_arrayref({});

$cv->begin;
do {

  foreach my $row (@$rs) {
    push @urls, {
      url => $row->{domain},
      cb => sub {
        my ($data,$srv,$domain) = @_;
        my $nfo = {};
        my $ids = {};
        $data =~ s/\r//g;

        while ($data =~ /^Registrant (.*?): (.*?)$/mgc) {
          print "registrant $1 => $2\n" if ($DEBUG);
          my $field = $dbField->{$1};
          $nfo->{'registrant'}->{$field} = $2;
        }
        while ($data =~ /^Admin (.*?): (.*?)$/mgc) {
          print "admin $1 => $2\n" if ($DEBUG);
          my $field = $dbField->{$1};
          $nfo->{'admin'}->{$field} = $2;
        }
        while ($data =~ /^Tech (.*?): (.*?)$/mgc) {
          print "tech $1 => $2\n" if ($DEBUG);
          my $field = $dbField->{$1};
          $nfo->{'tech'}->{$field} = $2;
        }

        foreach my $contact (qw/registrant admin tech/) {
          try {
            my @v = map { $nfo->{$contact}->{$_} } @f; 
            my $sql = sprintf("INSERT into whois_contact (%s) values (%s) %s%s",
              join(',',@f), join(',',@q),
              "on conflict(street, zip, phone, email)",
              "do nothing returning id"
            );
            print "$sql\n" if ($DEBUG);
            print join('',map { my $o = $_ || ""; "[$o]"; } @v)."\n" if ($DEBUG);
            my $sth = $dbh->prepare ($sql);
            $sth->execute (@v);
            my $rs = $sth->fetchall_arrayref({});
            $ids->{$contact} = $rs->[0]->{id};
          } catch {
          };
          if (not defined $ids->{$contact}) {
            my $sql = sprintf("select id from whois_contact where street = ? and zip = ? and phone = ? and email = ?");
            my $sth = $dbh->prepare($sql);
            my @v = map { $nfo->{$contact}->{$_} } qw/street zip phone email/;
            $sth->execute (@v);
            my $rs = $sth->fetchall_arrayref({});
            $ids->{$contact} = $rs->[0]->{id};
          }
        }

        my ($created, $updated);
        if ($data =~ /^Creation Date: (.*?)$/m) {
          $created = $1;
          print "created $created\n" if ($DEBUG);
        }
        if ($data =~ /^Updated Date: (.*?)$/m) {
          $updated = $1;
          print "updated $updated\n" if ($DEBUG)
        }
        try {
          my $sth = $dbh->prepare ("INSERT into whois_nfo (domain,created,updated,registrant,admin,tech) values (?,?,?,?,?,?) on conflict do nothing");
          $sth->execute($domain, $created, $updated, $ids->{'registrant'}, $ids->{admin}, $ids->{tech});
        } catch { 
        };

        try {
          my $sth = $dbh->prepare ("INSERT into whois_servers (url) values (?) on conflict(url) do nothing");
          $sth->execute ($srv);
          $sth->finish;
        } catch {
        };

        try {
          my $sth = $dbh->prepare ("update pending_whois set resolved = now() where domain = ?");
          $sth->execute ($domain);
          $sth->finish;
        } catch {
        };

        print "\n";
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
$cv->end;

$cv->recv;
