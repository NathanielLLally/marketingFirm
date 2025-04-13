#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Email::Sender::Simple qw(sendmail try_to_sendmail);
use Email::Sender::Transport::SMTPS;
use Email::Simple ();
use Email::Simple::Creator ();
use Email::MIME;
use Data::Dumper;
use Nginx::ParseLog;
use DBI;
use Try::Tiny;
use Config::Tiny;
use File::Basename;
use File::Spec;

my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($dirname, '..','etc','obiseo.conf');
our $CFG = Config::Tiny->read( $cfgFile );
my $logFile = File::Spec->catfile($dirname, '..','checkEmailTracking.log');
my $accessFile = File::Spec->catfile($dirname, '..','www','nginx_access.log');
open(PLOG, ">$logFile");

`rsync -avP -e "ssh -i /home/nathaniel/.ssh/awsFreeTier.pem" devel\@obiseo.net:/home/devel/nginx_access.log /home/nathaniel/src/git/marketingFirm/www`;

my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";


open(LOG, "<$accessFile") || die "cannot open nginx_access.log";

while (<LOG>) {
    my $parsed = Nginx::ParseLog::parse($_);
    if ($parsed->{request} =~ /GET \/img\/track\.png\?k=([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/) {
        print PLOG Dumper(\$parsed);
        my $uuid = $1;
            print PLOG "found tracking for $uuid\n";
            my $isth = $dbh->prepare ("insert into track_email_clicks (tag,clicked,email_uuid) values (?, ?, ?)");
            try {
                $isth->execute("viewed", $parsed->{time}, $uuid);
                $isth->finish;
            } catch {
            };
    } elsif ($parsed->{request} =~ /\?(\w+)=([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/) {
        my ($var, $uuid) = ($1,$2);
            print PLOG "found $var for $uuid\n";
            my $isth = $dbh->prepare ("insert into track_email_clicks (tag,clicked,email_uuid) values (?, ?, ?)");
        try {
            $isth->execute($var, $parsed->{time}, $uuid);
            $isth->finish;
        } catch {
        };
    }
}
close(LOG);
close(PLOG);

