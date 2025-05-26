#!/usr/bin/perl
use warnings;
use strict;
use feature 'isa';
use Try::Tiny;
use DBI;
use Carp qw/croak longmess/;
use Try::Tiny;
use DBI;
use Data::Dumper;
use Coro;
use AnyEvent;
use Coro::AnyEvent;
use AnyEvent::Whois::Raw;
use Time::HiRes qw(time gettimeofday tv_interval);
use Config::Tiny;
use File::Basename;
use File::Spec;

$Net::Whois::Raw::CHECK_FAIL = 1;

my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($dirname, '..','etc','obiseo.conf');
if (! -e $cfgFile) {
    $cfgFile = $ENV{HOME}."/.obiseo.conf";
}
print "using config $cfgFile\n";
our $CFG = Config::Tiny->read( $cfgFile );
print Dumper(\$CFG);

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
      PrintError => 0,
      PrintWarn => 0,
    }) or die "cannot connect: $DBI::errstr";

sub execReconnect
{
  my ($sth,@args) = @_;
  try {
    $sth->execute(@args);
  } catch {
    if ($_ =~ /no connection to the server/) {
      print "reconnecting to dB\n";
      $dbh = DBI->connect( $CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},
        { RaiseError => 1, }
      ) or die "cannot connect: $DBI::errstr";
    } else {
        die "uncaught dB error: $_\n";
    }
  };
}

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
      print "returned $url\t";
      $count--;
      my $data = shift;
      if ($data and $data =~ /\s*?[Dd]omain/) {
        my $srv = shift;
        $cb->($data,$srv,$url);
      }
      elsif (! defined $data) {
        my $srv = shift;
        print "no information for domain on $srv found\n";
      }
      else {
        my $reason = shift;
        print "whois error: $reason\t$data";
      }

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
  Organisation => 'organization',
  Street => 'street',
  City => 'city',
  'State' => 'state',
  'State/Province' => 'state',
  'State\Province' => 'state',
  Country => 'country',
  Phone => 'phone',
  'Phone Ext' => 'phone_ext',
  'PhoneExt' => 'phone_ext',
  'Postal Code' => 'zip',
  'PostalCode' => 'zip',
  'Fax' => 'fax',
  'FAX' => 'fax',
  'Fax Ext' => 'fax_ext',
  'FAX Ext' => 'fax_ext',
  'FaxExt' => 'fax_ext',
  Email => 'email'
};
my %vals = map { $_ => 1 }values %$dbField;
my @f = map { $_ } sort keys %vals; 
my @q = map { '?' } keys %vals;


my $sth = $dbh->prepare ("select domain from wi.pending where resolved is null and random() < 0.001 limit 10");
execReconnect($sth);
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

        my ($created, $updated, $expires);
        if ($data =~ /Creation Date: (.*?)$/m) {
          $created = $1;
          print "created $created\n" if ($DEBUG);
        }
        if ($data =~ /Updated Date: (.*?)$/m) {
          $updated = $1;
          print "updated $updated\n" if ($DEBUG)
        }
        if ($data =~ /Expir(y|ation) Date: (.*?)$/m) {
          $expires = $2;
          print "expires $expires\n" if ($DEBUG)
        }
        if ( defined $created ) {
          print "created $created\n";

        my $err;
        while ($data =~ /^\s*?Registrant (.*?):\s*?(.*?)$/mgc) {
          print "registrant $1 => $2\n" if ($DEBUG);
          my $field = $dbField->{$1};
          if (not defined $field and $1 ne 'ID') {
            print "\n***Missing field xlate for registrant [$1:$2]\n";
            $err = 1;
          }
          $nfo->{'registrant'}->{$field} = $2;
        }
        while ($data =~ /^\s*?Admin (.*?):\s*?(.*?)$/mgc) {
          print "admin $1 => $2\n" if ($DEBUG);
          my $field = $dbField->{$1};
          if (not defined $field and $1 ne 'ID') {
            print "\n***Missing field xlate for admin [$1:$2]\n";
            $err = 1;
          }
          $nfo->{'admin'}->{$field} = $2;
        }
        while ($data =~ /^\s*?Tech (.*?):\s*?(.*?)$/mgc) {
          print "tech $1 => $2\n" if ($DEBUG);
          my $field = $dbField->{$1};
          if (not defined $field and $1 ne 'ID') {
            print "\n***Missing field xlate for tech [$1:$2]\n";
            $err = 1;
          }
          $nfo->{'tech'}->{$field} = $2;
        }
        while ($data =~ /^\s*?Billing (.*?):\s*?(.*?)$/mgc) {
          print "billing $1 => $2\n" if ($DEBUG);
          my $field = $dbField->{$1};
          if (not defined $field and $1 ne 'ID') {
            print "\n***Missing field xlate for tech [$1:$2]\n";
            $err = 1;
          }
          $nfo->{'billing'}->{$field} = $2;
        }

        if (defined $err) {
          print $data;
        }

        foreach my $contact (qw/registrant admin tech billing/) {
          try {
            if ( exists $nfo->{$contact} ) {
                my @v   = map { $nfo->{$contact}->{$_} } @f;
                my $sql = sprintf(
                    "INSERT into wi.contact (%s) values (%s) %s%s",
                    join( ',', @f ),
                    join( ',', @q ),
                    "on conflict(street, zip, phone, email)",
                    "do nothing returning id"
                );
                print "$sql\n" if ($DEBUG);
                print join( '', map { my $o = $_ || ""; "[$o]"; } @v ) . "\n"
                  if ($DEBUG);
                my $sth = $dbh->prepare($sql);
                execReconnect( $sth, @v );
                my $rs = $sth->fetchall_arrayref( {} );
                $ids->{$contact} = $rs->[0]->{id};
            } else {
              #              print "no contact info $contact\t";
            }
          } catch {
            if ($_ =~ /violates check constraint/) {
              #print "bad email: ".$nfo->{$contact}->{email}."\n";
            } else {
              print $data;
              print "$_\n";
            }
          };

          if (not defined $ids->{$contact} and exists $nfo->{$contact}) {
            my $sql = sprintf("select id from wi.contact where street = ? and zip = ? and phone = ? and email = ?");
            my $sth = $dbh->prepare($sql);
            my @v = map { $nfo->{$contact}->{$_} } qw/street zip phone email/;
            execReconnect($sth,@v);
            my $rs = $sth->fetchall_arrayref({});
            $ids->{$contact} = $rs->[0]->{id};
          }
        }

            try {
                my $sth = $dbh->prepare(
"INSERT into wi.nfo (domain,created,updated,expires,registrant,admin,tech,billing) values (?,?,?,?,?,?,?,?) on conflict (domain) do update set updated=EXCLUDED.updated,expires=EXCLUDED.expires,registrant=EXCLUDED.registrant,admin=EXCLUDED.admin,tech=EXCLUDED.tech"
                );

#          $sth->execute($domain, $created, $updated, $ids->{'registrant'}, $ids->{admin}, $ids->{tech});
                execReconnect( $sth, $domain, $created, $updated, $expires,
                    $ids->{'registrant'}, $ids->{admin}, $ids->{tech}, $ids->{billing} );
            }
            catch {
            };

            #Rate limit exceeded. Try again after:
            #You have been banned for abuse.
            #You have exceeded your access quota. Please try again later
            #IP Address Has Reached Rate Limit
            try {
                my $sth = $dbh->prepare(
                    "update wi.pending set resolved = now() where domain = ?"
                );
                execReconnect( $sth, $domain );
                $sth->finish;
            }
            catch {
            };
        }
        print "\n";
      }};
    send_url();
  }

  while ($#urls > $maxQueue) {    
    Coro::AnyEvent::sleep 1;
    send_url();
  }

  execReconnect($sth);
  $rs = $sth->fetchall_arrayref({});

} while ($#{$rs} > -1);
$cv->end;

$cv->recv;
