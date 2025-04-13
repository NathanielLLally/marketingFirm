#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use feature 'isa';

use Parallel::ForkManager;
use DBI;
use Data::Dumper;
use List::Util qw(shuffle);
use Try::Tiny;

print `date`;

#close(STDOUT);
#close(STDERR);
#open(STDOUT, ">>$logfile");
#open(STDERR,">>$logfile");

my $dbh = DBI->connect("dbi:Pg:dbname=postgres;host=127.0.0.1", 'postgres', undef, {
      RaiseError => 1,
      InactiveDestroy => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";


my $file = shift @ARGV;
open(CSV,"<$file") || die "cannot open $file";
while (<CSV>) {
    if ($_ =~ /^\w/) {
        my ($domain, $mx) = split(/,/,$_);
        try {
my $sth = $dbh->prepare ("insert into mx_domain (domain) values (?)");
$sth->execute($domain);
$sth->finish;
} catch {
};

if (defined $mx and length($mx) > 0) {
        try {
my $sth = $dbh->prepare ("insert into mx_mx (host,did) select ? as host, id from mx_domain where domain = ?");
$sth->execute($mx, $domain);
$sth->finish;
} catch {
};
}

    }

}
close(CSV);


