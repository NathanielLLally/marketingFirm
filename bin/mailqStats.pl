#!/usr/bin/perl
use warnings;
use strict;
use Postfix::Parse::Mailq;
use Data::Dumper;
use DBI;
use Config::Tiny;
use Try::Tiny;

my $cfgFile = $ENV{HOME}."/.obiseo.conf";
our $CFG = Config::Tiny->read( $cfgFile );
my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      PrintError => 0,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";


  my $mailq_output = `mailq`;

  my $entries = Postfix::Parse::Mailq->read_string($mailq_output);
my $bytes = 0;

my $DEBUG = 1;
my $DRY = 1;
my %dup;
my %rcptForIds;
## Please see file perltidy.ERR
my %idForRcpt;
for my $el (@$entries) {
	#    print Dumper(\$el) if ($DEBUG);
    my $rcpt = ${ $el->{remaining_rcpts} }[0];
    $dup{$rcpt}++;
    $idForRcpt{ $el->{queue_id} } = $rcpt;
    push @{ $rcptForIds{$rcpt} }, $el;
}

## Please see file perltidy.ERR
foreach my $k (keys %dup) {
  if ($dup{$k} > 1) {
    printf "%u mails for %s\n", $dup{$k}, $k;

    my $anyError = undef;
    foreach my $el (@{$rcptForIds{$k}}) {

      printf "%s\t%s\t%s\n", $el->{queue_id}, $el->{date}, $el->{error_string} || "no error" if ($DEBUG);
      $anyError = $anyError."\n".$el->{error_string} if (defined $el->{error_string});
    }



    if (not $DRY) {
    if (defined $anyError) {
      print "there were errors, flusing all, marking as defered in track_email\n";
        my $isth = $dbh->prepare ("update track_email set defer = now() where email = ?");
        $isth->execute($k);
        $isth->finish;
    foreach my $el ( @{ $rcptForIds{$k} } ) {
        `postsuper -d $el->{queue_id}`;
      }
    } else {
      print "no errors, flusing all but first, marking as sent in track_email\n";
        my $isth = $dbh->prepare ("update track_email set sent = now() where email = ?");
        $isth->execute($k);
        $isth->finish;
## Please see file perltidy.ERR
      shift @{ $rcptForIds{$k }};
    foreach my $el ( @{ $rcptForIds{$k} } ) {
        `postsuper -d $el->{queue_id}`;
      }

    }
  }
  } else {
        my $isth = $dbh->prepare ("select pending,sent from track_email where email = ?");
        $isth->execute($k);
        my $rs = $isth->fetchall_arrayref({});
        foreach (@$rs) {
          printf "sinqle entry to: %s, db sent: %s error: %s\n", 
	  $k, $_->{sent}, @{ $rcptForIds{$k} }[0]->{error_string} || "no error";
        }
  }
}
