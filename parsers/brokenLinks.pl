#!/usr/bin/perl
use warnings;
use strict;

use DBI;
use DBD::CSV;
use IPC::Run qw( run timeout );
use LWP;
use LWP::Parallel;
use HTTP::Request;

#use LWP::Debug qw(+);
use Data::Dumper;

my @drivers = DBI->available_drivers;
print join(", ", @drivers), "\n";

my $file = shift @ARGV;
my ($dbh, @headers);

unless (defined $file and -e "$file") {
  print "cannot find [$file]\n";
  print "TODO::implement /dev/stdin\n\n";
  exit;
} 

#my $DSN = 'driver={};server=$server_name;database=$database_name;uid=$database_user;pwd=$database_pass;';
$dbh = DBI->connect("dbi:CSV:", undef, undef, {
    f_ext => ".csv/r",
    RaiseError => 1,
  }) or die "cannot connect: $DBI::errstr";

#        # Simple statements
#        $dbh->do ("CREATE TABLE foo (id INTEGER, name CHAR (10))");
        
my %ref;
my $sth = $dbh->prepare ("select * from $file");
$sth->execute;
  #        $sth->bind_columns (\my ($a, $b, $c, $d));
my $a = $sth->fetchall_arrayref(\%ref);


my %phoneByWebsite;
my %linktreeByWebsite;
my %websiteByLink;

print Dumper(\$a);
#Email,Name,Phone,Address,Website,....
#
#TODO: lc(headers)

foreach my $row (@$a) {
  if ((length $row->{phone} > 0) and (length $row->{website} > 0)) {
    $phoneByWebsite{$row->{website}} = $row->{phone};
  }
}

print Dumper(\%phoneByWebsite);

  # Updates
  #my $sth = $dbh->prepare ("UPDATE foo SET name = ? WHERE id = ?");
  #$sth->execute ("DBI rocks!", 1);
  $sth->finish;

$dbh->disconnect;

my $pua = LWP::Parallel::UserAgent->new();
$pua->in_order  (0);  # handle requests in order of registration
$pua->duplicates(1);  # ignore duplicates
$pua->timeout   (20);  # in seconds
$pua->redirect  (1);  # follow redirects

foreach my $k (keys %phoneByWebsite) {
  print "Registering '".$k."'\n";
  if ( my $res = $pua->register (HTTP::Request->new(GET=>$k)) ) { 
    print STDERR $res->error_as_HTML; 
  }  
}
my $entries = $pua->wait();


my ($in, $out, $err);
my @cmd = qw( parseURL.pl --output=url );

foreach (keys %$entries) {
  my $res = $entries->{$_}->response;

  print "Answer for '",$res->request->url, "' was \t", $res->code,"\n";

  $in = $res->decoded_content();
  run \@cmd, \$in, \$out, \$err, timeout( 10 ) or die "cat: $?";

  foreach my $line ($out) {
    chomp $line;
    print "\n\n$line\n\n";
    if (not exists $linktreeByWebsite{$res->request->url}) {
      $linktreeByWebsite{$res->request->url} = {};
    }
    $websiteByLink{$line} = $res->request->url;
    $linktreeByWebsite{$res->request->url}{$line}++;

    if ( my $res = $pua->register (HTTP::Request->new(GET=>$line)) ) { 
      print STDERR $res->error_as_HTML; 
    }  
  }
 exit; 
}

#
#
#
$entries = $pua->wait();

foreach (keys %$entries) {
  my $res = $entries->{$_}->response;

  print "Answer for '",$res->request->url, "' was \t", $res->code;
  $linktreeByWebsite{ $websiteByLink{$res->request->url} }{$res->request->url} = $res->code;
}

print Dumper(\%linktreeByWebsite);
